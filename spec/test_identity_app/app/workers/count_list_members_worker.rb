class CountListMembersWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'critical'

  def perform(id)
    list = List.find(id)
    list.update_attribute(:member_count, list.list_members.count)
  end
end
