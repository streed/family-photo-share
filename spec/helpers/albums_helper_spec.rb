require 'rails_helper'

RSpec.describe AlbumsHelper, type: :helper do
  let(:owner) { create(:user) }

  describe "#album_privacy_badge" do
    it "labels a private album" do
      album = create(:album, user: owner, privacy: "private")
      badge = helper.album_privacy_badge(album)

      expect(badge).to include("Private")
      expect(badge).to include("privacy-private")
      expect(badge).to include("Only you can see this album")
    end

    it "labels a family album" do
      album = create(:album, user: owner, privacy: "family")
      badge = helper.album_privacy_badge(album)

      expect(badge).to include("Family")
      expect(badge).to include("privacy-family")
    end

    it "names how many people a family album actually reaches" do
      family = create(:family, created_by: owner)
      2.times { create(:family_membership, user: create(:user), family: family) }
      album = create(:album, user: owner.reload, privacy: "family")

      expect(helper.album_privacy_badge(album, detailed: true)).to include("Family · 2 people")
    end

    it "does not claim an audience when the owner has no family" do
      album = create(:album, user: owner, privacy: "family")

      expect(owner.family).to be_nil
      expect(helper.album_privacy_badge(album, detailed: true)).to include("Family")
      expect(helper.album_privacy_badge(album, detailed: true)).not_to include("·")
    end

    it "escapes the markup it builds" do
      album = create(:album, user: owner, privacy: "private")
      expect(helper.album_privacy_badge(album)).to be_html_safe
    end
  end

  describe "#album_link_sharing_badge" do
    it "renders nothing when external sharing is off" do
      album = create(:album, user: owner, allow_external_access: false)
      expect(helper.album_link_sharing_badge(album)).to be_nil
    end

    it "flags an album shared by link" do
      album = create(:album, user: owner, allow_external_access: true)
      badge = helper.album_link_sharing_badge(album)

      expect(badge).to include("Link")
      expect(badge).to include("Anyone with the link")
    end

    it "says when the link is password protected" do
      album = create(:album, user: owner, allow_external_access: true, password: "hunter22")

      expect(helper.album_link_sharing_badge(album)).to include("Anyone with the link and password")
    end
  end

  describe "#album_privacy_description" do
    it "describes each privacy setting in plain language" do
      private_album = create(:album, user: owner, privacy: "private")
      family_album = create(:album, user: owner, privacy: "family", name: "Fam")

      expect(helper.album_privacy_description(private_album)).to eq("Only you can see this album")
      expect(helper.album_privacy_description(family_album)).to eq("Everyone in your family can see this album")
    end
  end
end
