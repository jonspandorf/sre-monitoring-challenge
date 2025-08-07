variable "ES_USERNAME" {
  type = string
  description = "The username for the Elasticsearch user"
  default = "elastic"
}

variable "ES_PASSWORD" {
  type = string
  sensitive = true
  description = "The password for the Elasticsearch user"
}

variable "alerts" {
  type = list(object({
    name = string
    rule_type_id = string
    interval = string
    enabled = bool
    notify_when = string
    tags = optional(list(string))
    params = object({
      aggType = optional(string)
      groupBy = optional(string)
      termSize = optional(number)
      timeWindowSize = optional(number)
      timeWindowUnit = optional(string)
      threshold = optional(list(number))
      thresholdComparator = optional(string)
      index = optional(list(string))
      timeField = optional(string)
      aggField = optional(string)
      termField = optional(string)
    })
  }))
  description = "List of Kibana alerting rules to create"
}