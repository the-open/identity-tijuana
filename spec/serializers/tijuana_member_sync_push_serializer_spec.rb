describe IdentityTijuana::TijuanaMemberSyncPushSerializer do
  context 'serialize' do
    before(:each) do
      clean_external_database

      @member = Member.create!(name: 'Freddy Kruger', email: 'nosleeptill@elmstreet.com')

      list = List.create(name: 'test list')
      ListMember.create(list: list, member: @member)
      Member.create!(name: 'Miles Davis', email: 'jazz@vibes.com')
      Member.create!(name: 'Yoko Ono')
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
