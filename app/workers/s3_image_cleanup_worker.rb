class S3ImageCleanupWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform
    keys = ['agent/', 'vendor/', 'buyer/' ]
    s3 = Aws::S3::Resource.new(region: 'eu-west-2')
    bucket = nil
    ENV['EMAIL_ENV'] == 'dev' ? bucket = 'prophety-image-uploads' : bucket = 'prpimgu'
    keys.each do |key_name|
      s3.bucket(bucket).objects(prefix: key_name).map(&:key).group_by{|t| t[6..-1].sub(/\..*/, '')}.select{|h,k| k.count > 1}.each do |h,k|
        url=Agents::Branches::AssignedAgent.find(h.to_i).image_url 
        file_name=File.basename(url)
        k.select{|t| 'agent/'+file_name != t }.each {|t| s3.bucket(bucket).object(t).delete }
      end
    end
  end
end

