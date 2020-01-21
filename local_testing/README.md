### Use this for running BATs against a local virtualbox bosh-lite director

By default, `test.sh` will:
* use the environment found in `~/deployments/vbox`
* use the latest stemcell found in `~/deployments/stemcells`. This can be
  overridden by setting `STEMCELL_TGZ`.
* pass `latest` as the stemcell version. This can updated in `bats-warden.yml`.

Execute the test.sh script to run. Depending on your configuration, certain
tests may fail (eg. static IP tests when no static IPs are configured).
