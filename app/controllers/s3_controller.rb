class S3Controller < ApplicationController

  ### Gets a presigned url for every file that has to be uploaded to S3
  ### curl -XGET 'http://localhost/s3/upload/url?file_name=vendor/picture.jpg'
  def presigned_url
    file_name = params[:file_name]
    key_name = Digest::MD5.hexdigest(file_name)
    params[:key]
    s3 = Aws::S3::Resource.new(region: 'eu-west-2')
    obj = s3.bucket('prophety-image-uploads').object(key_name)
    url = obj.presigned_url(:put, expires_in: 5 * 60)
    render json: { presigned_url: url  }, status: 200
  end

  ### Verify if the upload has happened or not
  ### curl -XGET 'http://localhost/s3/verify/upload?file_name=vendor/picture.jpg'
  def verify_upload
    file_name = params[:file_name]
    key_name = Digest::MD5.hexdigest(file_name)
    s3 = Aws::S3::Resource.new(region: 'eu-west-2')
    exists = !(s3.bucket('prophety-image-uploads').objects(prefix: key_name).map(&:key).empty?)
    render json: { exists: exists }, status: 200
  end
end