data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  alert_for     = "CloudTrailBreach"
  sns_topic_arn = "${var.sns_topic_arn == "" ? aws_sns_topic.default.arn : var.sns_topic_arn }"
  endpoints     = "${distinct(compact(concat(list(local.sns_topic_arn), var.additional_endpoint_arns)))}"
  region        = "${var.region == "" ? data.aws_region.current.name : var.region}"

  metric_name = ["${var.metric_name}"]

  metric_namespace = "${var.metric_namespace}"
  metric_value     = "1"

  filter_pattern = ["${var.filter_pattern}"]

  alarm_description = ["${var.alarm_description}"]
}

resource "aws_cloudwatch_log_metric_filter" "default" {
  count          = "${length(local.filter_pattern)}"
  name           = "${local.metric_name[count.index]}-filter"
  pattern        = "${local.filter_pattern[count.index]}"
  log_group_name = "${var.log_group_name}"

  metric_transformation {
    name      = "${local.metric_name[count.index]}"
    namespace = "${local.metric_namespace}"
    value     = "${local.metric_value}"
  }
}

resource "aws_cloudwatch_metric_alarm" "default" {
  count               = "${length(local.filter_pattern)}"
  alarm_name          = "${local.metric_name[count.index]}-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "${local.metric_name[count.index]}"
  namespace           = "${local.metric_namespace}"
  period              = "300"                                                                         // 5 min
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"
  threshold           = "${local.metric_name[count.index] == "ConsoleSignInFailureCount" ? "3" :"1"}"
  alarm_description   = "${local.alarm_description[count.index]}"
  alarm_actions       = ["${local.endpoints}"]
}

resource "aws_cloudwatch_dashboard" "main" {
  count          = "${var.create_dashboard == "true" ? 1 : 0}"
  dashboard_name = "CISBenchmark_Statistics_Combined"

  dashboard_body = <<EOF
 {
   "widgets": [
       {
          "type":"metric",
          "x":0,
          "y":0,
          "width":20,
          "height":16,
          "properties":{
             "metrics":[
               ${join(",",formatlist("[ \"${local.metric_namespace}\", \"%v\" ]", local.metric_name))}
             ],
             "period":300,
             "stat":"Sum",
             "region":"${var.region}",
             "title":"CISBenchmark Statistics"
          }
       }
   ]
 }
 EOF
}

resource "aws_cloudwatch_dashboard" "main_individual" {
  count          = "${var.create_dashboard == "true" ? 1 : 0}"
  dashboard_name = "CISBenchmark_Statistics_Individual"

  dashboard_body = <<EOF
 {
   "widgets": [
     ${join(",",formatlist(
       "{
          \"type\":\"metric\",
          \"x\":%v,
          \"y\":%v,
          \"width\":12,
          \"height\":6,
          \"properties\":{
             \"metrics\":[
                [ \"${local.metric_namespace}\", \"%v\" ]
            ],
          \"period\":300,
          \"stat\":\"Sum\",
          \"region\":\"${var.region}\",
          \"title\":\"%v\"
          }
       }
       ", local.layout_x, local.layout_y, local.metric_name, local.metric_name))}
   ]
 }
 EOF
}

locals {
  # Two Columns
  # Will experiment with this values
  layout_x = [0, 12, 0, 12, 0, 12, 0, 12, 0, 12, 0, 12, 0, 12, 0, 12]

  layout_y = [0, 0, 7, 7, 15, 15, 22, 22, 29, 29, 36, 36, 43, 43, 50, 50]
}
