### Use this for running BATs against a local virtualbox bosh-lite director

Before running, make sure to:

* Update stemcell version in bats-warden.yml
* Update stemcell path in bats-warden.env
* Update `BAT_PRIVATE_KEY` in bats-warden.env

Execute the test.sh script to run. Depending on your configuration, certain
tests may fail (eg. static IP tests when no static IPs are configured).
