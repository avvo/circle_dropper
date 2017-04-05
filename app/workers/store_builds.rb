#require 'net/http'

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
        artifacts = CircleCi::Build.artifacts(build['username'], build['reponame'], build['build_num'])
        if artifacts.success?
          if artifacts.body.size > 0
            artifacts.body.each do |artifact|
              uri = URI.parse(artifact['url'])
              uri.query = {'circle-token' => CircleCi.config.token}.to_query

              if uri.path.include?('circle-junit')
                artifact_data = Net::HTTP.get(uri)
                if artifact_data.present?
                  s3 = Aws::S3::Client.new

                  filename = uri.path.split('/').last;

                  project_name = "#{build['username']}_#{build['reponame']}"
                  suite_name = "SUITE=#{uri.path.split('/')[-2]}"
                  build_number = "build_number_#{build['build_num']}"


                  full_path = "#{project_name}/#{suite_name}/#{build_number}/#{filename}"

                  s3.put_object(
                    bucket: ENV['AWS_BUCKET'],
                    key: full_path,
                    body: artifact_data,
                    acl: 'authenticated-read',
                    content_type: "text/xml"
                  )
                else
                  warn "Artifact has no data - #{uri.to_s}"
                end
              end
            end
          else
            warn "No artifacts found for #{build['username']}/#{build['reponame']} build ##{build['build_num']} - #{build['build_url']}"
          end
        else
          raise 'Could not get artifact data'
        end
      end
    else
      raise 'Could not get recent build data'
    end
  end
end
