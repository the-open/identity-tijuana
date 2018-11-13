class List < ApplicationRecord
  include ReadWriteIdentity
  has_many :list_members

  def copy_to_redshift
    RedshiftDB.connection.transaction do
      RedshiftDB.connection.execute("DELETE FROM list_members WHERE list_id = #{self.id}")
      list_members.each_slice(10_000) do |slice|
        value_strings = []
        slice.each do |list_member|
          value_strings << "(#{list_member.id}, #{id}, #{list_member.member_id}, '#{list_member.created_at}', '#{list_member.updated_at}')"
        end
        RedshiftDB.connection.execute("INSERT INTO list_members (id, list_id, member_id, created_at, updated_at) VALUES #{value_strings.join(',')}")
      end
    end
  end
end
