# The tailnet policy file: groups, tags, auto-approvers, SSH and grants, and the tests Tailscale runs
# against every update. A change that fails a test is rejected by Tailscale before it takes effect,
# so the tests are what stands between a typo and locking every device out; see README.md.
#
# Kept as one file per top-level key in policy/, each a complete HuJSON object. They are joined
# as text, in this order, into the single document Tailscale stores. Tailscale stores it in
# hujsonfmt's layout and the provider compares text, so each file must stay in that layout.
locals {
  policy_parts = ["groups", "tagOwners", "autoApprovers", "ssh", "tests", "grants"]
  policy_files = { for p in local.policy_parts : p => file("${path.module}/policy/${p}.hujson") }

  policy = "{\n${join("", [for p in local.policy_parts : trimsuffix(trimprefix(local.policy_files[p], "{\n"), "}\n")])}}\n"
}

resource "tailscale_acl" "policy" {
  acl = local.policy

  lifecycle {
    precondition {
      condition     = alltrue([for f in values(local.policy_files) : startswith(f, "{\n") && endswith(f, "\n}\n")])
      error_message = "Each policy/*.hujson must open with \"{\" and close with \"}\", each on its own line."
    }
  }
}
