### This is a daily worker
class BranchLockedStatusUpdateWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform
    Rails.logger.info("BranchLockedStatusUpdateWorker_PROCESSING_STARTED")
    locked_branches = Agents::Branches::AssignedAgent.where(locked: true).where(locked_date: (Date.today - 30.days))
    locked_branches.each {|t| Rails.logger.info("BranchLockedStatusUpdateWorker_LOCKED_STATUS_#{t.id}")}
    locked_branches.update_all(locked: false, locked_date: nil)
    Rails.logger.info("BranchLockedStatusUpdateWorker_PROCESSING_FINISHED")
  end
end

