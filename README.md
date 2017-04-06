# circle_dropper

This system moves CircleCI junit artifacts into S3.  They could be retrieved by anything, including an awesome [JUnit visualizer](https://github.com/avvo/junit_visualizer).

CircleCI will produce JUnit artifacts using this gem: https://github.com/circleci/minitest-ci

These environment variables are required:

* CIRCLE_CI_TOKEN
* AWS_ACCESS_KEY_ID
* AWS_SECRET_ACCESS_KEY
* AWS_BUCKET
* AWS_REGION (where the bucket is you want to write to)

[Get a CircleCI token](https://circleci.com/account/api)

Learn more about [AWS environment variables](https://github.com/aws/aws-sdk-ruby)

This system uses sidekiq and redis.
