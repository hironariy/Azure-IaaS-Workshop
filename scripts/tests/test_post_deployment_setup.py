"""Regression tests for Bash post-deployment command transport."""

from pathlib import Path
import subprocess
import unittest


TEMPLATE = (
    Path(__file__).resolve().parents[1] / "post-deployment-setup.template.sh"
).read_text()
HELPERS = TEMPLATE.split("log_info() {", 1)[1].split(
    "# Main Script", 1
)[0]
HELPERS = "log_info() {" + HELPERS
STATE_CHECK = TEMPLATE.split(
    "# Check whether the replica set is already initialized (idempotency).", 1
)[1].split("# Wait for a PRIMARY", 1)[0]


class PostDeploymentSetupTests(unittest.TestCase):
    def run_probe(self, state="uninitialized", exit_code=0):
        # Emulate mongosh's OSC title prefix when SSH allocates a terminal.
        mock = r'''
az() {
    local arg tty=false remote_cmd=""
    for arg in "$@"; do
        remote_cmd="$arg"
        if [ "$arg" = "-t" ]; then tty=true; fi
    done
    if [ "$tty" = true ]; then
        printf '\033]0;mongosh mongodb://127.0.0.1:27017/\007'
    fi
    case "$remote_cmd" in
        *RSSTATE*)
            case "$TEST_STATE" in
                initialized) printf 'RSSTATE initialized 3\r\n' ;;
                uninitialized) printf 'RSSTATE uninitialized -\r\n' ;;
                missing) printf 'MongoServerSelectionError: connection refused\r\n' ;;
            esac
            return "$TEST_RC"
            ;;
        *RSINIT*) printf 'RSINIT ok=1\r\n' ;;
        *) printf 'Unexpected remote command\n' >&2; return 1 ;;
    esac
}
'''
        setup = f'''
set -e
RED="" GREEN="" YELLOW="" BLUE="" NC=""
BASTION_NAME=test-bastion RESOURCE_GROUP=test-rg
USERNAME=azureuser SSH_KEY=/test/key
DB_VM1_ID=test-vm DB_VM1_NAME=vm-db-az1-prod
DB_VM1_IP=10.0.3.4 DB_VM2_IP=10.0.3.5 DB_VM3_IP=10.0.3.6
REPLICA_SET_NAME=blogapp-rs0
TEST_STATE={state} TEST_RC={exit_code}
'''
        return subprocess.run(
            ["bash", "-s"],
            input=setup + mock + HELPERS + STATE_CHECK,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_should_initialize_when_interactive_terminal_prefix_is_disabled(self):
        result = self.run_probe()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("RSSTATE uninitialized -", result.stdout)
        self.assertIn("Replica set initiated", result.stdout)
        self.assertNotIn("\033]", result.stdout)

    def test_should_skip_initialization_when_three_members_already_exist(self):
        result = self.run_probe(state="initialized")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("already initialized (3 electable members)", result.stdout)
        self.assertNotIn("Replica set initiated", result.stdout)

    def test_should_report_remote_error_when_state_marker_is_missing(self):
        result = self.run_probe(state="missing")
        self.assertEqual(result.returncode, 1)
        self.assertIn("missing RSSTATE marker", result.stdout)
        self.assertIn("MongoServerSelectionError: connection refused", result.stdout)
        self.assertIn("Use -T (not -t)", result.stdout)
        self.assertNotIn("Replica set initiated", result.stdout)

    def test_should_reject_state_marker_when_transport_exits_nonzero(self):
        result = self.run_probe(exit_code=9)
        self.assertEqual(result.returncode, 1)
        self.assertIn("exit code 9", result.stdout)
        self.assertNotIn("Replica set initiated", result.stdout)


if __name__ == "__main__":
    unittest.main()
