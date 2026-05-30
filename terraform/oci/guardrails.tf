locals {
  fixed_capacity_quota_statements = [
    "zero compute-core quotas in ${var.quota_target}",
    "zero compute-memory quotas in ${var.quota_target}",
    "zero block-storage quotas in ${var.quota_target}",
    "zero compute-management quotas in ${var.quota_target}",
    "zero auto-scaling quotas in ${var.quota_target}",
    "zero load-balancer quotas in ${var.quota_target}",
    "set compute-core quota standard-a1-core-count to ${var.ocpus} in ${var.quota_target} where request.ad=${local.availability_domain}",
    "set compute-memory quota standard-a1-memory-count to ${var.memory_gb} in ${var.quota_target} where request.ad=${local.availability_domain}",
    "set block-storage quota total-storage-gb to ${var.boot_volume_size_gb} in ${var.quota_target} where request.ad=${local.availability_domain}",
    "set vcn quota vcn-count to 1 in ${var.quota_target} where request.region=${var.region}",
    "set vcn quota reserved-public-ip-count to 0 in ${var.quota_target} where request.region=${var.region}",
  ]
}

resource "oci_limits_quota" "fixed_capacity_guardrail" {
  count = var.enable_spending_guardrails ? 1 : 0

  compartment_id = var.tenancy_ocid
  description    = "Fixed-capacity guardrails for the ATM10 space server. Blocks accidental compute, storage, autoscaling, and load balancer expansion beyond the approved server footprint."
  name           = "${replace(var.name, "-", "_")}_fixed_capacity"
  statements     = concat(local.fixed_capacity_quota_statements, var.extra_quota_statements)
  freeform_tags  = local.common_tags
}

resource "oci_budget_budget" "monthly_server_budget" {
  count = var.enable_budget_alerts ? 1 : 0

  amount                 = var.monthly_budget_amount
  compartment_id         = var.tenancy_ocid
  description            = "Monthly soft spending monitor for the ATM10 space server compartment."
  display_name           = "${var.name}-monthly-budget"
  freeform_tags          = local.common_tags
  processing_period_type = "MONTH"
  reset_period           = "MONTHLY"
  target_type            = "COMPARTMENT"
  targets                = [var.compartment_ocid]
}

resource "oci_budget_alert_rule" "monthly_server_budget" {
  for_each = var.enable_budget_alerts ? var.budget_alert_rules : {}

  budget_id      = oci_budget_budget.monthly_server_budget[0].id
  description    = "Budget alert for the ATM10 space server."
  display_name   = "${var.name}-${each.key}"
  freeform_tags  = local.common_tags
  message        = "ATM10 space server OCI spend has crossed a configured budget threshold. Review the tenancy before adding resources."
  recipients     = length(var.budget_alert_recipients) > 0 ? join(",", var.budget_alert_recipients) : null
  threshold      = each.value.threshold
  threshold_type = each.value.threshold_type
  type           = each.value.type
}

resource "oci_identity_dynamic_group" "cost_shutdown" {
  count = var.enable_cost_shutdown ? 1 : 0

  compartment_id = var.tenancy_ocid
  description    = "ATM10 server instance principal for budget-triggered shutdown."
  matching_rule  = "instance.id = '${oci_core_instance.server.id}'"
  name           = "${replace(var.name, "-", "_")}_cost_shutdown"
}

resource "oci_identity_policy" "cost_shutdown" {
  count = var.enable_cost_shutdown ? 1 : 0

  compartment_id = var.tenancy_ocid
  description    = "Allow the ATM10 server to inspect its budget and stop itself when the shutdown threshold is reached."
  name           = "${replace(var.name, "-", "_")}_cost_shutdown"
  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.cost_shutdown[0].name} to read usage-budgets in tenancy",
    "Allow dynamic-group ${oci_identity_dynamic_group.cost_shutdown[0].name} to use instances in tenancy where request.permission='INSTANCE_POWER_ACTIONS'",
  ]
}
