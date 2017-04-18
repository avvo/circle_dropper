# circle_dropper

This system moves CircleCI junit artifacts into S3.  They could be retrieved by anything, including an awesome [JUnit visualizer](https://github.com/avvo/junit_visualizer).

CircleCI will produce JUnit artifacts using certain gems to format the output.

 * minitest: https://github.com/circleci/minitest-ci (simple drop-in gem, no configuring)
 * rspec: https://github.com/sj26/rspec_junit_formatter
    Example command: `bundle exec rspec --color --format progress --format RspecJunitFormatter --out $CIRCLE_TEST_REPORTS/test_results.xml`

These environment variables are required:

* CIRCLE_CI_TOKEN
* AWS_ACCESS_KEY_ID
* AWS_SECRET_ACCESS_KEY
* AWS_BUCKET
* AWS_REGION (where the bucket is you want to write to)

[Get a CircleCI token](https://circleci.com/account/api)

Learn more about [AWS environment variables](https://github.com/aws/aws-sdk-ruby)

Optional environment variables:

* BRANCHES - specify a csv of branches and we will pull only those.  For example if you want to collect data only for master, set BRANCHES=master
* REDIS_HOST
* REDIS_PORT
* SECRET_KEY_BASE (only required in production)

A docker image of this project is available at https://hub.docker.com/r/avvo/circle_dropper/
To set up fully in docker, deploy that container twice, and link one to the other.  Set the second linked container's deploy command to bin/sidekiq.  Then link a redis container (probably redis:3.0-alpine) to BOTH circle_dropper containers.  Then set the above required environment variables on the two circle_dropper containers.

This system uses sidekiq and redis.
