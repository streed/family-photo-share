require 'rails_helper'

RSpec.describe Album, "contributions" do
  let(:family) { create(:family, created_by: owner) }
  let(:owner) { create(:user) }
  let(:relative) { create(:user) }
  let(:outsider) { create(:user) }

  # The family factory makes its creator an admin member, so owner only needs a
  # relative added alongside them.
  before do
    create(:family_membership, user: relative, family: family)
    [ owner, relative ].each(&:reload)
  end

  describe "#contributable_by?" do
    it "is true for a family member of the owner when the album is open" do
      album = create(:album, user: owner, privacy: "family", allow_contributions: true)

      expect(album.contributable_by?(relative)).to be true
    end

    it "is false for the owner, who is covered by editable_by?" do
      album = create(:album, user: owner, privacy: "family", allow_contributions: true)

      expect(album.contributable_by?(owner)).to be false
      expect(album.photos_addable_by?(owner)).to be true
    end

    it "is false for someone in a different family" do
      album = create(:album, user: owner, privacy: "family", allow_contributions: true)

      expect(album.contributable_by?(outsider)).to be false
    end

    it "is false when the owner has not opened the album up" do
      album = create(:album, user: owner, privacy: "family", allow_contributions: false)

      expect(album.contributable_by?(relative)).to be false
    end

    it "is false for nobody at all" do
      album = create(:album, user: owner, privacy: "family", allow_contributions: true)

      expect(album.contributable_by?(nil)).to be false
    end
  end

  describe "making an album private" do
    it "closes contributions, so the setting never lies about the album" do
      album = create(:album, user: owner, privacy: "family", allow_contributions: true)

      album.update!(privacy: "private")

      expect(album.allow_contributions).to be false
      expect(album.contributable_by?(relative)).to be false
    end
  end

  describe "#photo_removable_by?" do
    let(:album) { create(:album, user: owner, privacy: "family", allow_contributions: true) }
    let(:owners_photo) { create(:photo, user: owner) }
    let(:relatives_photo) { create(:photo, user: relative) }

    it "lets the owner remove anything" do
      expect(album.photo_removable_by?(relatives_photo, owner)).to be true
      expect(album.photo_removable_by?(owners_photo, owner)).to be true
    end

    it "lets a contributor remove only what they put in" do
      expect(album.photo_removable_by?(relatives_photo, relative)).to be true
      expect(album.photo_removable_by?(owners_photo, relative)).to be false
    end

    it "lets nobody else remove anything" do
      expect(album.photo_removable_by?(relatives_photo, outsider)).to be false
    end
  end

  describe ".addable_by" do
    let!(:own) { create(:album, user: relative, privacy: "private") }
    let!(:open_family) { create(:album, user: owner, privacy: "family", allow_contributions: true) }
    let!(:closed_family) { create(:album, user: owner, privacy: "family", allow_contributions: false) }
    let!(:outsiders) { create(:album, user: outsider, privacy: "family", allow_contributions: true) }

    it "covers your own albums and open family albums, and nothing else" do
      expect(Album.addable_by(relative)).to contain_exactly(own, open_family)
    end

    it "falls back to your own albums when you have no family" do
      expect(Album.addable_by(outsider)).to contain_exactly(outsiders)
    end

    it "is empty for nobody" do
      expect(Album.addable_by(nil)).to be_empty
    end
  end

  describe "#contributors" do
    it "names the family members who may add, and nobody when it is closed" do
      open_album = create(:album, user: owner, privacy: "family", allow_contributions: true)
      closed = create(:album, user: owner, privacy: "family", allow_contributions: false)

      expect(open_album.contributors).to contain_exactly(relative)
      expect(closed.contributors).to be_empty
    end
  end
end
