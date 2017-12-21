### This is a daily worker
class BranchLockedStatusUpdateWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform
    Agents::Branch.where(locked: true).where(locked_date: (Date.today - 30.days)).update_all(locked: false, locked_date: nil)
  end
end

