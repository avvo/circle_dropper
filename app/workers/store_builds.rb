class StoreBuilds
  include Sidekiq::Worker
  include Sidetiq::Schedulable

  sidekiq_options backtrace: true,
                  retry: false

  recurrence do
    minutely(5)
  end

  def perform
    recent_builds = CircleCi::RecentBuilds.get
    if recent_builds.success?
      recent_builds.body.each do |build|
        process_build(build)
      end
    else
      raise 'Could not get recent build data'
    end
  end

  private

  def process_build(build)
    artifacts = CircleCi::Build.artifacts(build['username'], build['reponame'], build['build_num'])
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

    if junit_artifact?(uri)
      artifact_data = Net::HTTP.get(uri)
      if artifact_data.present?
        save_in_s3(uri, build, artifact_data)
      else
        warn "Artifact has no data - #{uri.to_s}"
      end
    end
  end

  def junit_artifact?(uri)
    uri.path.include?('circle-junit')
  end

  def artifact_s3_path(uri, build)
    filename = uri.path.split('/').last;

    project_name = "#{build['username']}_#{build['reponame']}"
    suite_name = "SUITE=#{uri.path.split('/')[-2]}"
    build_number = "build_number_#{build['build_num']}"

    "#{project_name}/#{suite_name}/#{build_number}/#{filename}"
  end

  def save_in_s3(uri, build, artifact_data)
    s3 = Aws::S3::Client.new

    s3.put_object(
        bucket: ENV['AWS_BUCKET'],
        key: artifact_s3_path(uri, build),
        body: artifact_data,
        acl: 'authenticated-read',
        content_type: "text/xml"
    )
  end

end
