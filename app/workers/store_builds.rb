class StoreBuilds
  include Sidekiq::Worker
  include Sidetiq::Schedulable

  sidekiq_options backtrace: true,
                  retry: false

  recurrence do
    hourly.minute_of_hour(0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55)
  end

  def perform
    recent_builds = CircleCi::RecentBuilds.new

    builds = recent_builds.get
    if builds.success?
      builds.body.each do |build|
        if process_build?(build)
          process_build(build)
        end
      end
    else
      raise 'Could not get recent build data'
    end
  end

  private

  def process_build(build)
    circleci_build = CircleCi::Build.new(build['username'], build['reponame'], nil, build['build_num'])
    artifacts = circleci_build.artifacts
    if artifacts.success?
      if artifacts.body.size > 0
        artifacts.body.each do |artifact|
          process_artifact(build, artifact)
        end
      else
        warn "No artifacts found for #{build['username']}/#{build['reponame']} build ##{build['build_num']} - #{build['build_url']}"
      end
    else
      raise 'Could not get artifact data'
    end
  end

  def process_artifact(build, artifact)
    uri = URI.parse(artifact['url'])
    uri.query = {'circle-token' => CircleCi.config.token}.to_query

    puts "found uri: #{uri}"

    if junit_artifact?(uri)
      artifact_data = Net::HTTP.get(uri)

      s3_key = artifact_s3_path(uri, build)

      if present_in_s3?(s3_key)
        warn "Artifact already present in s3 - #{uri.to_s} for #{build['username']}/#{build['reponame']} build ##{build['build_num']} - #{build['build_url']}"
      else
        if artifact_data.present?
          save_in_s3(s3_key, artifact_data)
        else
          warn "Artifact has no data - #{uri.to_s} for #{build['username']}/#{build['reponame']} build ##{build['build_num']} - #{build['build_url']}"
        end
      end
    end
  end

  def junit_artifact?(uri)
    uri.path.include?('circle-junit')
  end

  def artifact_s3_path(uri, build)
    filename = uri.path.split('/').last;

    project_name = "#{build['username']}_#{build['reponame']}"

    suite = uri.path.split('/')[-2]
    suite = build['reponame'] if suite == "circle-junit"

    suite_name = "SUITE=#{suite}"
    build_number = "build_number_#{build['build_num']}"

    "#{project_name}/#{suite_name}/#{build_number}/#{filename}"
  end

  def save_in_s3(s3_key, artifact_data)
    s3 = Aws::S3::Client.new

    s3.put_object(
        bucket: ENV['AWS_BUCKET'],
        key: s3_key,
        body: artifact_data,
        acl: 'authenticated-read',
        content_type: "text/xml",
    )
  end

  def present_in_s3?(s3_key)
    s3 = Aws::S3::Client.new

    s3.get_object(
        bucket: ENV['AWS_BUCKET'],
        key: s3_key,
    )
    true
  rescue Aws::S3::Errors::NoSuchKey
    false
  end

  def process_build?(build)
    branches.blank? || branches.include?(build['branch'].downcase)
  end

  def branches
    @branches ||= ENV.fetch('BRANCHES', '').split(',').map(&:strip).map(&:downcase)
  end

end
