class UpdateMemberAreasWorker
  include Sidekiq::Worker

  def perform(id)
    # Member can get merged before the job is executed so we need to check they exist still
    if member = Member.find_by_id(id)
      member.update_areas
    end
    ActiveRecord::Base.clear_active_connections!
  end
end
