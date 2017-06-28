# BOSH Acceptance Tests

The BOSH Acceptance Tests are meant to be used to verify the commonly used functionality of BOSH.

**Note**: If you're just getting started with BATs, please refer to and use the [gocli-bats](https://github.com/cloudfoundry/bosh-acceptance-tests/tree/gocli-bats) branch which uses the newer [bosh CLI v2](http://bosh.io/docs/cli-v2.html). This `master` branch is being retained until all existing pipelines have migrated tests away from the Ruby CLI to the new CLI.

It requires a BOSH deployment, either a deployed micro bosh stemcell, or a full bosh-release deployment.

See [running bats](https://github.com/cloudfoundry/bosh/blob/master/docs/running_tests.md#bosh-acceptance-tests-bats) for how to run them.
