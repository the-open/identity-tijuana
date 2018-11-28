describe IdentityTijuana::TijuanaMemberSyncPushSerializer do
  context 'serialize' do
    before(:each) do
      clean_external_database

      @member = FactoryBot.create(:member)
      list = FactoryBot.create(:list)
      FactoryBot.create(:list_member, list: list, member: @member)
      FactoryBot.create(:member)
      FactoryBot.create(:member_without_email)

      @batch_members = Member.all.with_email.in_batches.first
    end

    it 'returns valid object' do
      rows = ActiveModel::Serializer::CollectionSerializer.new(
        @batch_members,
        serializer: IdentityTijuana::TijuanaMemberSyncPushSerializer,
        tag: 'test_tag',
      ).as_json
      expect(rows.count).to eq(2)
      expect(rows[0][:email]).to eq(ListMember.first.member.email)
    end
  end
end
