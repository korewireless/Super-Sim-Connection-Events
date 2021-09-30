# super-sim-connection-events

This repo contains scripts and configuration files to accompany our Super SIM Connection Events with AWS ElasticSearch and Kibana tutorial, which you can find in [Twilio docs](https://www.twilio.com/docs/iot/supersim/how-to-monitor-super-sim-connection-events-using-aws-elasticsearch-and-kibana). They are used in [Step 3](https://www.twilio.com/docs/iot/supersim/how-to-monitor-super-sim-connection-events-using-aws-elasticsearch-and-kibana#3-build-out-your-aws-resources) of the tutorial and depend on tools installed during the previous step of the tutorial.

Transfer all three files to your project directory:

* `setup_aws.sh`
* `validate_sink.sh`
* `supersim_events.tf`

`setup_aws.sh` is run in [Step 3](https://www.twilio.com/docs/iot/supersim/how-to-monitor-super-sim-connection-events-using-aws-elasticsearch-and-kibana#3-build-out-your-aws-resources) of the tutorial. To make use of the script `setup_aws.sh` you will need to edit the file and enter your AWS region.

`validate_sink.sh` is run in [Step 5](https://www.twilio.com/docs/iot/supersim/how-to-monitor-super-sim-connection-events-using-aws-elasticsearch-and-kibana#5-configure-twilio-event-streams-2-validate-the-sink) and passed the name of your AWS stream name (default: `supersim-connection-events-stream`) as its first argument.

**Note** You must run `setup_aws.sh` before you run `validate_sink.sh`, or the latter will issue errors because the required AWS resources have not yet been put in place. `setup_aws.sh` calls `terraform` to set up the required AWS resources.

## Important

The tutorial creates and uses AWS resources, so please be aware that this will come at a cost to your AWS account holder. We’ve made sure we used as few and as limited resources as possible. For more details, [check out AWS’ pricing page](https://aws.amazon.com/pricing/).

You may also find that certain configurations are not available in your preferred AWS region, so you may need to modify the config you use accordingly. Make sure you thoroughly review the file `supersim_events.tf`, which has all the details of the config you’ll use and will be where you’ll make any changes you need.

## Contributions

Contributions are welcome. Please target pull requests to the `develop` branch only.

All third-party contributors acknowledge that any contributions they provide will be made under the same [MIT license](LICENSE.md) that the open source project is provided under.

## License and Copyright

The scripts and files in this repo are © 2021, Twilio, Inc. They are licensed under the terms of the [MIT License](LICENSE.md).