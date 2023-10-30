/*
 * Version 1.0.0
 * Copyright © 2021, KORE Wireless
 * Licence: MIT
 */

/*
 * Define Terraform variables
 * These are set in the 'setup_aws.sh' script
 */
variable "your_aws_region" {
  type = string
}

// This is required to give your computer access to Kibana
variable "your_computer_external_ip" {
  type    = string
}

// Randomly generated string to verify connections from KORE
variable "external_id" {
  type = string
}

/*
 * Base Terraform setup
 */
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.42.0"
    }
  }

  required_version = ">= 0.15.0"
}

provider "aws" {
  profile = "default"
  region  = var.your_aws_region
}

/*
 * Set up policies
 */

// Create a Policy to permit KORE to write records to our Kinesis Stream
resource "aws_iam_policy" "supersim_kinesis_stream_record_write_policy" {
  name           = "supersim-kinesis-stream-record-write-policy"
  policy         = jsonencode({
    Version      = "2012-10-17"
    Statement    = [
      {
        Effect   = "Allow"
        Resource = "*"
        Action   = [
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ]
      },
      {
        Effect   = "Allow"
        Resource = "*"
        Action   = [
          "kinesis:ListShards",
          "kinesis:DescribeLimits"
        ]
      }
    ]
  })
}

// Create a policy to provide read access to ElasticSearch Kibana
// NOTE We limit access to your computer's external (eg. router) IP address,
//      which is required for web access to Kibana
resource "aws_elasticsearch_domain_policy" "supersim_elasticsearch_kibana_access_policy" {
  domain_name     = aws_elasticsearch_domain.supersim_elastic_search_kibana_domain.domain_name
  access_policies = jsonencode({
    Version       = "2012-10-17"
    Statement     = [
      {
        Action    = [
            "es:ESHttp*",
            "es:DescribeElasticsearchDomain",
            "es:ListDomainNames",
            "es:ListTags"
        ]
        Effect    = "Allow"
        Resource  =  "${aws_elasticsearch_domain.supersim_elastic_search_kibana_domain.arn}/*"
        Principal = {
          "AWS": "*"
        }
        Condition = {
          "IpAddress": {
            "aws:SourceIp": [
              var.your_computer_external_ip
            ]
          }
        }
      }
    ]
  })
}

// Set up a policy to manage Firehose's access to various resources:
//   * To write records to ElasticSearch
//   * To read from ElasticSearch (may not be necessary)
//   * To write to S3 records it could not write to ElasticSearch
//   * To read records from the Kinesis Data Stream
//   * To access EC2 resources for data transfer (may not be necessary)
resource "aws_iam_policy" "supersim_firehose_rw_access_policy" {
  name           = "supersim-firehose-rw-access-policy"
  policy         = jsonencode({
    Version      = "2012-10-17"
    Statement    = [
      {
        Effect   = "Allow"
        Action   = [
          "es:DescribeElasticsearchDomain",
          "es:DescribeElasticsearchDomains",
          "es:DescribeElasticsearchDomainConfig",
          "es:ESHttpPost",
          "es:ESHttpPut"
        ]
        Resource = [
          "${aws_elasticsearch_domain.supersim_elastic_search_kibana_domain.arn}",
          "${aws_elasticsearch_domain.supersim_elastic_search_kibana_domain.arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = [
          "es:ESHttpGet"
        ]
        Resource = [
          "${aws_elasticsearch_domain.supersim_elastic_search_kibana_domain.arn}",
          "${aws_elasticsearch_domain.supersim_elastic_search_kibana_domain.arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
           "${aws_s3_bucket.supersim_failed_report_bucket.arn}",
           "${aws_s3_bucket.supersim_failed_report_bucket.arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards"
        ]
        Resource = aws_kinesis_stream.supersim_connection_events_stream.arn
      },
      {
        Effect   = "Allow"
        Action   = [
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeNetworkInterfaces",
          "ec2:CreateNetworkInterface",
          "ec2:CreateNetworkInterfacePermission",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}


/*
 * Set up roles
 */

// Create a Role KORE will assume to access the Stream
resource "aws_iam_role" "supersim_twilio_access_role" {
  name                 = "supersim-twilio-access-role"
  assume_role_policy   = jsonencode({
    Version            = "2012-10-17"
    Statement          = [
      {
        Action         = "sts:AssumeRole"
        Effect         = "Allow"
        Principal      = {
          "AWS" = "arn:aws:iam::177261743968:root"
        }
        Condition      = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      }
    ]
  })
}

// Create a Role Firehose will assume to access ElasticSearch
resource "aws_iam_role" "supersim_firehose_access_role" {
  name               = "supersim-firehose-access-role"
  assume_role_policy = jsonencode({
    Version          = "2012-10-17"
    Statement        = [
      {
        Effect       = "Allow"
        Action       = "sts:AssumeRole"
        Principal    = {
          "Service" = "firehose.amazonaws.com"
        }
      }
    ]
  })
}


/*
 * Attach policies to roles
 */

// Attach the Stream write Policy to the KORE access Role
resource "aws_iam_role_policy_attachment" "supersim_attach_write_policy_to_twilio_access_role" {
  role       = aws_iam_role.supersim_twilio_access_role.name
  policy_arn = aws_iam_policy.supersim_kinesis_stream_record_write_policy.arn
}

// Attach the resource read/write/access Policy to the Firehose access Role
resource "aws_iam_role_policy_attachment" "supersim_attach_rw_policy_to_firehose_access_role" {
  role       = aws_iam_role.supersim_firehose_access_role.name
  policy_arn = aws_iam_policy.supersim_firehose_rw_access_policy.arn
}


/*
 * Set up AWS resources
 */

// Set up a Kinesis Stream to receive streamed events
// NOTE One shard is sufficient to the tutorial and testing
resource "aws_kinesis_stream" "supersim_connection_events_stream" {
  name        = "supersim-connection-events-stream"
  shard_count = 1
}

// Create our Elastic Search Domain
// This uses minimal server resources for the tutorial, but
// a real-world application would require greater resources
resource "aws_elasticsearch_domain" "supersim_elastic_search_kibana_domain" {
  domain_name           = "supersim-es-kibana-domain"
  elasticsearch_version = "7.10"

  cluster_config {
    instance_type  = "t2.small.elasticsearch"
    instance_count = 1
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "standard"
    volume_size = 25
  }

  domain_endpoint_options {
      enforce_https = true
      tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }
}

// Create an S3 Bucket
// This is used by Firehose to dump records it could not pass
// to ElasticSearch. In a real-world app, you might also choose
// to store all received records
data "aws_canonical_user_id" "current_user" {}

resource "aws_s3_bucket" "supersim_failed_report_bucket" {
    bucket        = "supersim-failed-report-bucket"
    grant {
      id          = data.aws_canonical_user_id.current_user.id
      type        = "CanonicalUser"
      permissions = ["FULL_CONTROL"]
  }
}

// Create a Kinesis Firehose to link the Kinesis Data Stream (input)
// to ElasticSearch (output)
resource "aws_kinesis_firehose_delivery_stream" "supersim_firehose_pipe" {
  name        = "supersim-firehose-pipe"
  destination = "elasticsearch"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.supersim_connection_events_stream.arn
    role_arn           = aws_iam_role.supersim_firehose_access_role.arn
  }

  elasticsearch_configuration {
    domain_arn     = aws_elasticsearch_domain.supersim_elastic_search_kibana_domain.arn
    role_arn       = aws_iam_role.supersim_firehose_access_role.arn
    index_name     = "super-sim"

    processing_configuration {
      enabled = "false"
    }
  }

  s3_configuration {
    role_arn        = aws_iam_role.supersim_firehose_access_role.arn
    bucket_arn      = aws_s3_bucket.supersim_failed_report_bucket.arn
    buffer_interval = 60
    buffer_size     = 1
  }
}


/*
 * Outputs -- useful values printed at the end
 */
output "EXTERNAL_ID" {
  value       = var.external_id
  description = "The External ID you will use to create your KORE Event Streams Sink"
}

output "KIBANA_WEB_URL" {
  value       = aws_elasticsearch_domain.supersim_elastic_search_kibana_domain.kibana_endpoint
  description = "The URL you will use to access Kibana"
}

output "COMPUTER_IP_ADDRESS" {
  value       = var.your_computer_external_ip
}

output "YOUR_KINESIS_STREAM_ARN" {
  value       = aws_kinesis_stream.supersim_connection_events_stream.arn
}

output "YOUR_KINESIS_ROLE_ARN" {
  value       = aws_iam_role.supersim_twilio_access_role.arn
}
