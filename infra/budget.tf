# ---------------------------------------------------------------------------
# Budget: a tripwire for the day this stack stops being free.
#
# Account wide, not scoped to this project: nothing here carries tags, so a
# cost filter has nothing to match on. That is fine while this is the only
# stack in the account, and wrong the moment it isn't.
#
# Cost budgets with email notification are free and unlimited. Only
# action-enabled budgets are metered, and this one takes no actions.
# ---------------------------------------------------------------------------
resource "aws_budgets_budget" "monthly" {
  name         = "${var.project}-monthly"
  budget_type  = "COST"
  limit_amount = var.budget_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Charges have already happened.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  # AWS projects the month will end over the limit. Needs a few days of
  # history before it can forecast anything, so it stays quiet at first.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}
