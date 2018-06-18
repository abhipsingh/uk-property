module Agents
  module Branches
    class CrawledProperty < ActiveRecord::Base
      belongs_to :branch, class_name: 'Agents::Branch'
      PST_MAP = {
        'Green' => 1,
        'Amber' => 2,
        'Red' => 3
      }

      REVERSE_PST_MAP = PST_MAP.invert

      def self.images_from_aws(stored_response)
        s3 = Aws::S3::Resource.new
        images = []
        stored_response['image_urls'].map{ |t| File.basename(t) }.each do |image|
          obj = s3.bucket('propertyuk').object(image)
          images.push(obj.presigned_url(:get, expires_in: 300))
        end
        images
      end
    end

  end
  
end

