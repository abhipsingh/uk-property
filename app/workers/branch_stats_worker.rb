class BranchStatsWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform
    Rails.logger.info("BranchStatsWorker_PROCESSING_STARTED")
    Agents::Branch.find_in_batches do |group|
      group.each do |each_branch|
        Rails.logger.info("BranchStatsWorker_PROCESSING_STARTED_#{each_branch.id}")
        each_branch.branch_specific_stats
        Rails.logger.info("BranchStatsWorker_PROCESSING_FINISHED_#{each_branch.id}")
      end
    end
    Rails.logger.info("BranchStatsWorker_PROCESSING_FINISHED")
  end
end

