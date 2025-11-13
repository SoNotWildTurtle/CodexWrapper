import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
CX_PATH = REPO_ROOT / "cx"


def _base_env(tmp_home: Path) -> dict:
    env = os.environ.copy()
    env["HOME"] = str(tmp_home)
    env["CX_HOME"] = str(tmp_home / ".cx")
    return env


def _init_git_repo(path: Path, env: dict) -> None:
    subprocess.run(
        ["git", "init"],
        cwd=path,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
    )
    subprocess.run(
        ["git", "config", "user.email", "tester@example.com"],
        cwd=path,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
    )
    subprocess.run(
        ["git", "config", "user.name", "Test User"],
        cwd=path,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
    )
    subprocess.run(
        ["git", "add", "-A"],
        cwd=path,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
    )
    subprocess.run(
        ["git", "commit", "-m", "initial"],
        cwd=path,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
    )


class ModuleWorkflowTests(unittest.TestCase):
    def test_modules_json_output_includes_python_component(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            (project / "src" / "pkg").mkdir(parents=True)
            (project / "src" / "pkg" / "module.py").write_text(
                "def foo():\n    return 42\n", encoding="utf-8"
            )
            (project / "tests").mkdir()
            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)

            subprocess.run(
                [str(CX_PATH), "--modules=json"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
            )

            modules_dir = Path(env["CX_HOME"]) / "modules"
            files = sorted(modules_dir.glob("proj-*.json"))
            self.assertTrue(files, "No module analysis file generated")
            data = json.loads(files[-1].read_text(encoding="utf-8"))
            self.assertIn("python", data)
            self.assertIn("missing_init", data["python"])
            self.assertIn("src/pkg", data["python"]["missing_init"])
            components = data["python"]["components"]
            self.assertIn("src/pkg", components)
            self.assertEqual(components["src/pkg"]["files"], 1)

            decisions = data.get("decisions", {})
            self.assertIn("immediate", decisions)
            self.assertTrue(
                any(
                    entry.get("component") == "src/pkg"
                    and "Missing __init__.py" in entry.get("reasons", [])
                    for entry in decisions["immediate"]
                ),
                "Immediate decisions should flag src/pkg for missing __init__.py",
            )

            weak_points = data.get("weak_points", [])
            self.assertTrue(weak_points, "Weak points should be captured in module analysis")
            target = next(
                (entry for entry in weak_points if entry.get("component") == "src/pkg"),
                None,
            )
            self.assertIsNotNone(target, "src/pkg should appear in weak points list")
            self.assertGreaterEqual(target.get("score", 0), 4)
            self.assertIn(
                "Missing __init__.py",
                target.get("reasons", []),
                "Weak point reasons should include missing __init__.py",
            )

            plan = data.get("mitigation_plan")
            self.assertIsInstance(plan, dict, "Mitigation plan should be present in module JSON")
            automated = plan.get("automated", [])
            manual = plan.get("manual", [])
            self.assertTrue(
                any(
                    entry.get("action") == "Add __init__.py"
                    and entry.get("component") == "src/pkg"
                for entry in automated
                ),
                "Automated plan should include Add __init__.py task for src/pkg",
            )
            self.assertTrue(
                any(
                    entry.get("action") == "Create Python tests"
                    and entry.get("component") == "src/pkg"
                for entry in automated
                ),
                "Automated plan should suggest creating Python tests",
            )
            self.assertTrue(
                any(
                    entry.get("action", "").lower().startswith("investigate")
                    for entry in manual
                ),
                "Manual mitigation plan should include weak-point investigation",
            )
            self.assertTrue(
                all(entry.get("severity") for entry in automated),
                "Automated mitigations should include severity labels",
            )

            summary = data.get("decision_summary")
            self.assertIsInstance(summary, dict, "Decision summary should be included")
            self.assertGreaterEqual(
                summary.get("immediate", 0), 1, "Immediate decisions should be tallied",
            )

    def test_estimate_detail_writes_per_field_metrics(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            project.mkdir()

            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)
            cx_home = Path(env["CX_HOME"])
            cx_home.mkdir(parents=True, exist_ok=True)
            env["CX_DISABLE_MINT"] = "1"
            (cx_home / "dict").write_text(
                "@dev=You are a seasoned developer.\n",
                encoding="utf-8",
            )

            proc = subprocess.run(
                [
                    str(CX_PATH),
                    "role=@dev",
                    "goal=demo",
                    "--estimate-detail",
                    "--dry",
                ],
                cwd=project,
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
                input="\n" * 10,
                text=True,
            )

            self.assertIn(proc.returncode, (0, 1), "Wrapper should exit cleanly or with the dry-run code path")
            stderr = proc.stderr
            self.assertIn("raw=", stderr, "Summary token savings should be printed to stderr")
            self.assertIn("field=role", stderr, "Field-level savings should include the role facet")
            self.assertIn("field=goal", stderr, "Field-level savings should include the goal facet")

            metrics_path = cx_home / "metrics" / "proj.log"
            self.assertTrue(metrics_path.exists(), "Metrics log should be created for the project")
            lines = [line.strip() for line in metrics_path.read_text(encoding="utf-8").splitlines() if line.strip()]
            self.assertGreaterEqual(len(lines), 3, "Metrics log should include summary and per-field entries")
            self.assertTrue(
                any("field=role" in line for line in lines),
                "Metrics log should contain per-field entries",
            )

    def test_estimate_summary_reports_aggregates(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            project.mkdir()

            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)

            metrics_dir = Path(env["CX_HOME"]) / "metrics"
            metrics_dir.mkdir(parents=True, exist_ok=True)
            metrics_path = metrics_dir / "proj.log"
            metrics_path.write_text(
                """
[2025-01-01T0000Z] raw=100 compressed=80 savings=20%
[2025-01-02T0000Z] raw=120 compressed=90 savings=25%
[2025-01-02T0000Z] field=goal raw=60 compressed=45 savings=25%
[2025-01-02T0000Z] field=role raw=40 compressed=32 savings=20%
""".strip(),
                encoding="utf-8",
            )

            result = subprocess.run(
                [str(CX_PATH), "--estimate-summary"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
                text=True,
            )

            output = result.stdout
            self.assertIn("Token metrics summary for proj", output)
            self.assertIn("Runs logged: 2", output)
            self.assertIn("Weighted average savings", output)
            self.assertIn("Per-field averages", output)
            self.assertIn("goal: runs=1", output)

    def test_config_report_lists_layered_defaults(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            project.mkdir()
            (project / ".cx").mkdir()

            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)

            user_cx = Path(env["CX_HOME"])
            user_cx.mkdir(parents=True, exist_ok=True)
            (user_cx / "config").write_text("role=global-role\ngoal=global-goal\n", encoding="utf-8")

            project_config = project / ".cx" / "config"
            project_config.write_text("goal=project-goal\ncons=project-cons\n", encoding="utf-8")

            extra_config = tmp_path / "extra.cfg"
            extra_config.write_text("reason=extra-reason\n", encoding="utf-8")
            env["CX_CONFIG"] = str(extra_config)

            result = subprocess.run(
                [str(CX_PATH), "--config", "goal=cli-goal"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
                text=True,
            )

            output = result.stdout
            self.assertIn("# Configuration overview", output)
            self.assertIn(str(user_cx / "config"), output)
            self.assertIn(str(project_config), output)
            self.assertIn(str(extra_config), output)
            self.assertIn("- role=global-role", output)
            self.assertIn("- goal=project-goal", output)
            self.assertIn("- reason=extra-reason", output)
            self.assertIn("goal=cli-goal", output)
            self.assertIn("cons=project-cons", output)

    def test_config_env_exports_shell_assignments(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            project.mkdir()
            (project / ".cx").mkdir()

            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)

            user_cx = Path(env["CX_HOME"])
            user_cx.mkdir(parents=True, exist_ok=True)
            (user_cx / "config").write_text("role=team lead\n", encoding="utf-8")

            project_config = project / ".cx" / "config"
            project_config.write_text("goal=ship release\ncons=keep focus\n", encoding="utf-8")

            result = subprocess.run(
                [str(CX_PATH), "--config-env", "reason=Focus on tests"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
                text=True,
            )

            lines = result.stdout.strip().splitlines()
            self.assertTrue(lines and lines[0].startswith("# Shell exports"))
            self.assertTrue(any(line.startswith("export CX_ROLE=") for line in lines))
            self.assertTrue(any("export CX_GOAL=" in line and "ship\\ release" in line for line in lines))
            self.assertTrue(any("export CX_CONS=" in line and "keep\\ focus" in line for line in lines))
            self.assertTrue(any("export CX_REASON=" in line and "Focus\\ on\\ tests" in line for line in lines))

    def test_config_env_supports_powershell_format(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            project.mkdir()

            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)

            user_cx = Path(env["CX_HOME"])
            user_cx.mkdir(parents=True, exist_ok=True)
            (user_cx / "config").write_text("role=analyst\n", encoding="utf-8")

            result = subprocess.run(
                [str(CX_PATH), "--config-env=powershell", "goal=Investigate spaces"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
                text=True,
            )

            lines = result.stdout.strip().splitlines()
            self.assertTrue(lines and lines[0].startswith("# PowerShell environment"))
            self.assertTrue(any(line.startswith("Set-Item -Path Env:CX_ROLE") for line in lines))
            self.assertTrue(any("Env:CX_GOAL" in line and "'Investigate spaces'" in line for line in lines))

    def test_config_which_reports_key_origins(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            project.mkdir()
            (project / ".cx").mkdir()

            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)
            env["CX_MODEL"] = "gpt-4"

            user_cx = Path(env["CX_HOME"])
            user_cx.mkdir(parents=True, exist_ok=True)
            (user_cx / "config").write_text("goal=global-goal\n", encoding="utf-8")

            project_config = project / ".cx" / "config"
            project_config.write_text("model=project-model\n", encoding="utf-8")

            result = subprocess.run(
                [str(CX_PATH), "--config-which=goal,model", "goal=cli-goal"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
                text=True,
            )

            output = result.stdout
            self.assertIn("# Config resolution", output)
            self.assertIn("## goal", output)
            self.assertIn("default: global-goal", output)
            self.assertIn("cli: cli-goal", output)
            self.assertIn("resolved: cli-goal", output)
            self.assertIn("## model", output)
            self.assertIn("default: project-model", output)
            self.assertIn("env: CX_MODEL=gpt-4", output)
            self.assertIn("resolved: project-model", output)

    def test_config_list_groups_entries_by_source(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            project.mkdir()
            (project / ".cx").mkdir()

            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)

            user_config = Path(env["CX_HOME"]) / "config"
            user_config.parent.mkdir(parents=True, exist_ok=True)
            user_config.write_text("role=global-role\n", encoding="utf-8")

            project_config = project / ".cx" / "config"
            project_config.write_text("goal=project-goal\ncons=project-cons\n", encoding="utf-8")

            extra_config = tmp_path / "extra.cfg"
            extra_config.write_text("reason=extra-reason\n", encoding="utf-8")
            env["CX_CONFIG"] = str(extra_config)

            result = subprocess.run(
                [str(CX_PATH), "--config-list"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=env,
            )

            output = result.stdout
            self.assertIn("# Config entries by source", output)
            self.assertIn(f"## {user_config}", output)
            self.assertIn("  - role=global-role", output)
            self.assertIn(f"## {project_config}", output)
            self.assertIn("  - goal=project-goal", output)
            self.assertIn("  - cons=project-cons", output)
            self.assertIn(f"## {extra_config}", output)
            self.assertIn("  - reason=extra-reason", output)

    def test_config_diff_reports_differences(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            project.mkdir()
            (project / ".cx").mkdir()

            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)

            user_config = Path(env["CX_HOME"]) / "config"
            user_config.parent.mkdir(parents=True, exist_ok=True)
            user_config.write_text("role=global-role\ncons=shared\n", encoding="utf-8")

            project_config = project / ".cx" / "config"
            project_config.write_text("goal=project-goal\ncons=project-cons\n", encoding="utf-8")

            result = subprocess.run(
                [str(CX_PATH), "--config-diff=user:project"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=env,
            )

            output = result.stdout
            self.assertIn("# Config diff", output)
            self.assertIn(str(user_config), output)
            self.assertIn(str(project_config), output)
            self.assertIn('- role: user="global-role" (missing from project)', output)
            self.assertIn('- goal: project="project-goal" (missing from user)', output)
            self.assertIn('- cons: user="shared" vs project="project-cons"', output)

    def test_config_template_outputs_sample(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            project.mkdir()

            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)

            result = subprocess.run(
                [str(CX_PATH), "--config-template=user"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=env,
            )

            output = result.stdout
            self.assertIn("# cx configuration template (user scope)", output)
            self.assertIn(str(Path(env["CX_HOME"]) / "config"), output)
            self.assertIn("role=You are a seasoned developer.", output)

    def test_config_edit_creates_and_opens_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            project.mkdir()
            (project / ".cx").mkdir()

            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)

            editor = tmp_path / "fake-editor.sh"
            editor.write_text(
                "#!/usr/bin/env bash\ncat <<'EOF' > \"$1\"\nrole=script-role\ngoal=script-goal\nEOF\n",
                encoding="utf-8",
            )
            editor.chmod(0o755)
            env["CX_CONFIG_EDITOR"] = str(editor)

            result = subprocess.run(
                [str(CX_PATH), "--config-edit"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
                text=True,
            )

            project_config = project / ".cx" / "config"
            self.assertTrue(project_config.exists(), "Config file should be created during --config-edit")
            contents = project_config.read_text(encoding="utf-8")
            self.assertIn("role=script-role", contents)
            self.assertIn("goal=script-goal", contents)
            self.assertIn("Launching editor", result.stderr)

    def test_config_reset_removes_requested_scope(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            project.mkdir()

            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)

            user_config = Path(env["CX_HOME"]) / "config"
            user_config.parent.mkdir(parents=True, exist_ok=True)
            user_config.write_text("role=old-role\n", encoding="utf-8")

            result = subprocess.run(
                [str(CX_PATH), "--config-reset=user"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=env,
            )

            self.assertFalse(user_config.exists(), "User config file should be removed by --config-reset")
            self.assertIn("Removed config file", result.stderr)

    def test_config_export_writes_snapshot(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            project.mkdir()
            (project / ".cx").mkdir()

            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)

            project_config = project / ".cx" / "config"
            project_config.write_text("role=archivist\nmodel=gpt-4\n", encoding="utf-8")

            export_path = tmp_path / "snapshot.cfg"
            subprocess.run(
                [str(CX_PATH), f"--config-export={export_path}"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
            )

            contents = export_path.read_text(encoding="utf-8")
            self.assertIn("# cx configuration snapshot", contents)
            self.assertIn("role=archivist", contents)
            self.assertIn("model=gpt-4", contents)
            self.assertIn(str(project_config), contents)

    def test_config_validate_flags_unknown_and_invalid_entries(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            (project / ".cx").mkdir(parents=True)

            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)

            project_config = project / ".cx" / "config"
            project_config.write_text("role=\ntemp=5\n", encoding="utf-8")

            user_config = Path(env["CX_HOME"]) / "config"
            user_config.parent.mkdir(parents=True, exist_ok=True)
            user_config.write_text("unknown=1\n", encoding="utf-8")

            result = subprocess.run(
                [str(CX_PATH), "--config-validate"],
                cwd=project,
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
                text=True,
            )

            self.assertNotEqual(result.returncode, 0, "Validation should fail when config issues exist")
            self.assertIn("Config validation", result.stdout)
            self.assertIn("Unknown config key 'unknown'", result.stdout)
            self.assertIn("Config key 'role'", result.stdout)
            self.assertIn("outside the allowed 0-2 range", result.stdout)

    def test_config_validate_passes_when_defaults_are_clean(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            (project / ".cx").mkdir(parents=True)

            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)

            project_config = project / ".cx" / "config"
            project_config.write_text("role=@dev\ngoal=ship\ntemp=0.8\n", encoding="utf-8")

            result = subprocess.run(
                [str(CX_PATH), "--config-validate=project"],
                cwd=project,
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
                text=True,
            )

            self.assertEqual(result.returncode, 0, f"Unexpected failure: {result.stdout}\n{result.stderr}")
            self.assertIn("Validation passed with no issues", result.stdout)

    def test_config_import_updates_config_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            project.mkdir()
            (project / ".cx").mkdir()

            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)

            target_config = project / ".cx" / "config"
            target_config.write_text("role=old-role\n", encoding="utf-8")

            import_file = tmp_path / "import.cfg"
            import_file.write_text("goal=new-goal\ncons=new-cons\n", encoding="utf-8")

            subprocess.run(
                [str(CX_PATH), f"--config-import={import_file}"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
            )

            updated = target_config.read_text(encoding="utf-8")
            self.assertIn("role=old-role", updated)
            self.assertIn("goal=new-goal", updated)
            self.assertIn("cons=new-cons", updated)

    def test_modules_apply_updates_mitigation_status(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            (project / "src" / "pkg").mkdir(parents=True)
            (project / "src" / "pkg" / "module.py").write_text(
                "def foo():\n    return 42\n", encoding="utf-8"
            )
            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)
            subprocess.run(
                [str(CX_PATH), "--modules=apply"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
            )

            modules_dir = Path(env["CX_HOME"]) / "modules"
            module_jsons = sorted(modules_dir.glob("proj-*.json"))
            self.assertTrue(module_jsons, "Apply mode should emit module analysis JSON")
            data = json.loads(module_jsons[-1].read_text(encoding="utf-8"))
            plan = data.get("mitigation_plan", {})
            automated = plan.get("automated", [])

            def status_for(action: str) -> str:
                for entry in automated:
                    if (
                        entry.get("component") == "src/pkg"
                        and entry.get("action") == action
                    ):
                        return entry.get("status", "")
                self.fail(f"Mitigation action {action!r} not found in automated plan")

            self.assertEqual(
                status_for("Add __init__.py"),
                "completed",
                "Applying modules should complete Add __init__.py mitigation",
            )
            self.assertEqual(
                status_for("Create Python tests"),
                "completed",
                "Applying modules should complete Python test scaffolding",
            )


    def test_scaffold_creates_python_package_and_tests(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            (project / "src" / "pkg").mkdir(parents=True)
            (project / "src" / "pkg" / "module.py").write_text(
                "def foo():\n    return 42\n", encoding="utf-8"
            )
            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)

            subprocess.run(
                [str(CX_PATH), "--scaffold"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
            )

            package_init = project / "src" / "pkg" / "__init__.py"
            self.assertTrue(package_init.exists(), "__init__.py was not created")
            self.assertIn("Auto-generated", package_init.read_text(encoding="utf-8"))

            tests_dir = project / "tests"
            self.assertTrue(tests_dir.exists(), "tests directory was not created")
            generated_tests = list(tests_dir.glob("test_*.py"))
            self.assertTrue(generated_tests, "No scaffolded test file created")

            scaffold_logs = Path(env["CX_HOME"]) / "scaffold"
            self.assertTrue(
                list(scaffold_logs.glob("proj-*.md")), "Scaffold log was not created"
            )

    def test_config_set_and_unset_manage_files(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            project.mkdir()

            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)

            result = subprocess.run(
                [
                    str(CX_PATH),
                    "--config-set=goal=ship MVP",
                    "--config-set=reason=Focus quality",
                ],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
                text=True,
            )
            self.assertIn("Wrote config", result.stderr)

            project_config = project / ".cx" / "config"
            self.assertTrue(project_config.exists(), "Project config file was not created")
            content = project_config.read_text(encoding="utf-8")
            self.assertIn("goal=ship MVP", content)
            self.assertIn("reason=Focus quality", content)

            subprocess.run(
                [str(CX_PATH), "--config-unset=goal"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
            )
            content_after_unset = project_config.read_text(encoding="utf-8")
            self.assertNotIn("goal=ship MVP", content_after_unset)
            self.assertIn("reason=Focus quality", content_after_unset)

            subprocess.run(
                [str(CX_PATH), "--config-unset=reason"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
            )
            self.assertFalse(project_config.exists(), "Config file should be removed when empty")

            result_user = subprocess.run(
                [str(CX_PATH), "--config-set=model=gpt-4.1", "--config-scope=user"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
                text=True,
            )
            self.assertIn("Wrote config", result_user.stderr)

            user_config = Path(env["CX_HOME"]) / "config"
            self.assertTrue(user_config.exists(), "User config file was not created")
            user_content = user_config.read_text(encoding="utf-8")
            self.assertIn("model=gpt-4.1", user_content)

    def test_additive_references_scaffold_logs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            (project / "src" / "pkg").mkdir(parents=True)
            (project / "src" / "pkg" / "module.py").write_text(
                "def foo():\n    return 42\n", encoding="utf-8"
            )
            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)
            env.update(
                {
                    "CX_IMPROVE_SKIP_INSTALL": "1",
                    "CX_IMPROVE_SKIP_TESTS": "1",
                }
            )

            _init_git_repo(project, env)

            subprocess.run(
                [str(CX_PATH), "--additive=apply"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
            )

            scaffold_logs = sorted(
                (Path(env["CX_HOME"]) / "scaffold").glob("proj-*.md")
            )
            self.assertTrue(
                scaffold_logs, "No scaffold log captured during additive run"
            )

            additive_logs = sorted(
                (Path(env["CX_HOME"]) / "additive").glob("proj-*.md")
            )
            self.assertTrue(additive_logs, "No additive report generated")
            latest_additive = additive_logs[-1].read_text(encoding="utf-8")
            self.assertIn("_Mode: Apply_", latest_additive)
            self.assertIn("Scaffolding run:", latest_additive)
            self.assertNotIn("not yet executed", latest_additive.lower())
            self.assertIn("Quick module tasks", latest_additive)
            self.assertIn("Create tests for Python module src/pkg", latest_additive)
            self.assertTrue(
                any(
                    phrase in latest_additive
                    for phrase in (
                        "Prioritize Python module src/pkg",
                        "Plan for Python module src/pkg",
                    )
                ),
                "Additive report should surface module decision guidance",
            )
            self.assertIn("Module analysis JSON:", latest_additive)
            referenced = None
            for line in latest_additive.splitlines():
                if line.startswith("- Scaffolding run:"):
                    referenced = line.split(":", 1)[1].strip()
                    break
            self.assertTrue(referenced, "Additive report did not reference scaffold log")
            self.assertTrue(
                Path(referenced).exists(), "Referenced scaffold log path does not exist"
            )

            module_jsons = sorted(
                (Path(env["CX_HOME"]) / "modules").glob("proj-*.json")
            )
            self.assertTrue(module_jsons, "No module JSON snapshot captured")
            data = json.loads(module_jsons[-1].read_text(encoding="utf-8"))
            self.assertIn("python", data)
            self.assertIn("no_tests", data["python"])

    def test_additive_full_includes_module_mode_and_scaffolding(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            (project / "pkg").mkdir(parents=True)
            (project / "pkg" / "module.py").write_text(
                "def foo():\n    return 42\n", encoding="utf-8"
            )
            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)
            env.update(
                {
                    "CX_IMPROVE_SKIP_INSTALL": "1",
                    "CX_IMPROVE_SKIP_TESTS": "1",
                }
            )

            _init_git_repo(project, env)

            subprocess.run(
                [str(CX_PATH), "--additive=full"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
            )

            scaffold_logs = sorted(
                (Path(env["CX_HOME"]) / "scaffold").glob("proj-*.md")
            )
            self.assertTrue(
                scaffold_logs, "Full additive mode did not generate scaffold log"
            )

            additive_logs = sorted(
                (Path(env["CX_HOME"]) / "additive").glob("proj-*.md")
            )
            self.assertTrue(additive_logs, "No additive report generated for full mode")
            latest_additive = additive_logs[-1].read_text(encoding="utf-8")
            self.assertIn("_Mode: Full_", latest_additive)
            self.assertIn("Module-building opportunities", latest_additive)
            self.assertIn("Scaffolding run:", latest_additive)
            self.assertNotIn("not yet executed", latest_additive.lower())
            self.assertIn("Quick module tasks", latest_additive)
            self.assertIn("Module analysis JSON:", latest_additive)

    def test_module_regression_detection_blocks_new_gaps(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            (project / "src" / "pkg").mkdir(parents=True)
            (project / "src" / "pkg" / "__init__.py").write_text(
                "# package init\n", encoding="utf-8"
            )
            (project / "src" / "pkg" / "module.py").write_text(
                "def foo():\n    return 42\n", encoding="utf-8"
            )
            (project / "tests" / "pkg").mkdir(parents=True)
            (project / "tests" / "pkg" / "test_pkg.py").write_text(
                "import pkg\n\n\ndef test_placeholder():\n    assert pkg.module.foo() == 42\n",
                encoding="utf-8",
            )

            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)

            subprocess.run(
                [str(CX_PATH), "--modules=json"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
            )

            modules_dir = Path(env["CX_HOME"]) / "modules"
            latest_baseline = modules_dir / "proj-latest.json"
            self.assertTrue(latest_baseline.exists(), "Baseline JSON was not created")

            (project / "src" / "newpkg").mkdir(parents=True)
            (project / "src" / "newpkg" / "module.py").write_text(
                "def bar():\n    return 7\n", encoding="utf-8"
            )

            regression = subprocess.run(
                [str(CX_PATH), "--modules=json"],
                cwd=project,
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
            )
            self.assertNotEqual(
                regression.returncode, 0, "Regression guard should block new gaps"
            )
            self.assertIn("Module regression", regression.stderr.decode())

            baseline_data = json.loads(latest_baseline.read_text(encoding="utf-8"))
            self.assertNotIn(
                "src/newpkg",
                baseline_data["python"]["missing_init"],
                "Regression run should not update the baseline",
            )

            env_allow = env.copy()
            env_allow["CX_MODULE_ALLOW_REGRESSION"] = "1"
            allowed = subprocess.run(
                [str(CX_PATH), "--modules=json"],
                cwd=project,
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env_allow,
            )
            self.assertEqual(allowed.returncode, 0, allowed.stderr.decode())
            self.assertIn("allowed", allowed.stderr.decode().lower())

            updated_baseline = json.loads(latest_baseline.read_text(encoding="utf-8"))
            self.assertIn(
                "src/newpkg",
                updated_baseline["python"]["missing_init"],
                "Allowed regression should refresh the baseline",
            )

    def test_modules_flags_todo_markers(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            (project / "src" / "pkg").mkdir(parents=True)
            (project / "src" / "pkg" / "__init__.py").write_text(
                "# package init\n", encoding="utf-8"
            )
            (project / "src" / "pkg" / "module.py").write_text(
                "def foo():\n    # TODO: refine implementation\n    return 42\n",
                encoding="utf-8",
            )
            (project / "tests" / "pkg").mkdir(parents=True)
            (project / "tests" / "pkg" / "test_pkg.py").write_text(
                "import pkg\n\n\ndef test_placeholder():\n    assert pkg.module.foo() == 42\n",
                encoding="utf-8",
            )

            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)

            subprocess.run(
                [str(CX_PATH), "--modules=json"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
            )

            modules_dir = Path(env["CX_HOME"]) / "modules"
            files = sorted(modules_dir.glob("proj-*.json"))
            self.assertTrue(files, "Module analysis snapshot missing")
            data = json.loads(files[-1].read_text(encoding="utf-8"))

            decisions = data.get("decisions", {})
            all_entries = (
                decisions.get("immediate", [])
                + decisions.get("short_term", [])
                + decisions.get("monitor", [])
            )
            self.assertTrue(
                any(
                    entry.get("component") == "src/pkg"
                    and any("TODO/FIXME" in reason for reason in entry.get("reasons", []))
                    for entry in all_entries
                ),
                "Module decisions should surface TODO marker guidance",
            )

            weak_points = data.get("weak_points", [])
            todo_entry = next(
                (entry for entry in weak_points if entry.get("component") == "src/pkg"),
                None,
            )
            self.assertIsNotNone(todo_entry, "Weak points should include TODO-heavy module")
            self.assertIn(
                "TODO/FIXME markers present",
                " ".join(todo_entry.get("reasons", [])),
                "Weak point reasons should mention TODO markers",
            )


class DoctorCommandTests(unittest.TestCase):
    def test_doctor_reports_python_and_creates_log(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            project.mkdir()
            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)

            result = subprocess.run(
                [str(CX_PATH), "--doctor"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
                text=True,
            )

            self.assertIn("[OK] python3", result.stdout)
            self.assertIn("Overall status:", result.stdout)

            doctor_dir = Path(env["CX_HOME"]) / "doctor"
            logs = sorted(doctor_dir.glob("proj-*.md"))
            self.assertTrue(logs, "Doctor command should produce a log file")
            self.assertTrue(
                (doctor_dir / "proj-latest.md").exists(),
                "Doctor command should update latest pointer",
            )


class WeakPointCommandTests(unittest.TestCase):
    def test_weakpoints_command_emits_summary_and_json(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            (project / "src" / "pkg").mkdir(parents=True)
            (project / "src" / "pkg" / "module.py").write_text(
                "def foo():\n    return 42\n", encoding="utf-8"
            )
            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)

            result = subprocess.run(
                [str(CX_PATH), "--weakpoints"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
                text=True,
            )

            self.assertIn("Weak point triage", result.stdout)

            weak_dir = Path(env["CX_HOME"]) / "weakpoints"
            json_logs = sorted(weak_dir.glob("proj-*.json"))
            md_logs = sorted(weak_dir.glob("proj-*.md"))
            self.assertTrue(json_logs, "Weak point JSON snapshot missing")
            self.assertTrue(md_logs, "Weak point Markdown summary missing")
            self.assertTrue(
                (weak_dir / "proj-latest.md").exists(),
                "Weak point summary should update latest pointer",
            )
            self.assertTrue(
                (weak_dir / "proj-latest.json").exists(),
                "Weak point JSON should update latest pointer",
            )

            summary_text = (weak_dir / "proj-latest.md").read_text(encoding="utf-8")
            self.assertIn("Run `cx --modules=apply`", summary_text)


class RecommendationsCommandTests(unittest.TestCase):
    def test_recommendations_command_outputs_summary_and_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            project.mkdir()
            (project / "recommendations.md").write_text(
                """# Backlog\n\n## R1\nStatus: ✅ Completed\n\n## R2\nStatus: ⏳ Planned\n""",
                encoding="utf-8",
            )

            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)

            result = subprocess.run(
                [str(CX_PATH), "--recommendations"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=env,
            )

            self.assertIn("Recommendations summary", result.stdout)
            self.assertIn("Completed:", result.stdout)
            self.assertIn("Pending:", result.stdout)
            self.assertIn("## R2", result.stdout)

    def test_recommendations_command_filters_by_status(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            project.mkdir()
            (project / "recommendations.md").write_text(
                """# Backlog\n\n## R1\nStatus: ✅ Completed\nSub-notes:\n- done\n\n## R2\nStatus: ⏳ Planned\nSub-notes:\n- pending\n\n## Auto-generated Summaries\n\n- placeholder\n""",
                encoding="utf-8",
            )

            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)

            result = subprocess.run(
                [
                    str(CX_PATH),
                    "--recommendations",
                    "--recommendations-filter=planned",
                ],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=env,
            )

            self.assertIn("Applied status filters", result.stdout)
            self.assertIn("## R2", result.stdout)
            self.assertNotIn("## R1", result.stdout)

    def test_recommendations_command_supports_search_terms(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            project.mkdir()
            (project / "recommendations.md").write_text(
                """# Backlog\n\n## R1\nStatus: ⏳ Planned\nSub-notes:\n- improve lint\n\n## R2\nStatus: ⏳ Planned\nSub-notes:\n- update docs\n""",
                encoding="utf-8",
            )

            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)

            result = subprocess.run(
                [
                    str(CX_PATH),
                    "--recommendations",
                    "--recommendations-search=lint",
                ],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=env,
            )

            self.assertIn("Applied search terms", result.stdout)
            self.assertIn("## R1", result.stdout)
            self.assertNotIn("## R2", result.stdout)

    def test_improve_appends_auto_summary_entry(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            project.mkdir()
            (project / "recommendations.md").write_text(
                """# Backlog\n\n## R1\nStatus: ⏳ Planned\nSub-notes:\n- placeholder\n\n## Auto-generated Summaries\n\n- (auto summaries will be appended here after `cx --improve` runs)\n""",
                encoding="utf-8",
            )

            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)
            Path(env["CX_HOME"]).mkdir(parents=True, exist_ok=True)
            env["CX_IMPROVE_SKIP_INSTALL"] = "1"
            env["CX_IMPROVE_SKIP_TESTS"] = "1"
            env["CX_DISABLE_MINT"] = "1"

            subprocess.run(
                [str(CX_PATH), "--improve"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=env,
            )

            text = (project / "recommendations.md").read_text(encoding="utf-8")
            self.assertNotIn("auto summaries will be appended", text)
            self.assertRegex(text, r"## Auto-generated Summaries[\s\S]*- [✅⚠️] ")


class ConfigDefaultsTests(unittest.TestCase):
    def test_config_defaults_seed_arguments(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            project = tmp_path / "proj"
            project.mkdir()
            (project / ".cx").mkdir()
            (project / ".cx" / "config").write_text(
                "role=Project role\ngoal=Project goal\n", encoding="utf-8"
            )

            env_home = tmp_path / "home"
            env_home.mkdir()
            env = _base_env(env_home)
            cx_home = Path(env["CX_HOME"])
            cx_home.mkdir(parents=True, exist_ok=True)
            (cx_home / "config").write_text(
                "role=Global role\ngoal=Global goal\nreason=Global reason\nout=summary\n",
                encoding="utf-8",
            )

            extra_config = tmp_path / "extra.conf"
            extra_config.write_text(
                "goal=Final goal\ncons=Keep responses short\n", encoding="utf-8"
            )
            env["CX_CONFIG"] = str(extra_config)

            result = subprocess.run(
                [str(CX_PATH), "--estimate", "--dry"],
                cwd=project,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=env,
            )

            self.assertIn("::r Project role", result.stdout)
            self.assertIn("::g Final goal", result.stdout)
            self.assertIn("::c Keep responses short", result.stdout)
            self.assertIn("::s Global reason", result.stdout)
            self.assertIn("::o summary", result.stdout)


if __name__ == "__main__":
    unittest.main()
