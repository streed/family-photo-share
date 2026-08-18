require "rails_helper"

RSpec.describe IpLocation do
  describe "#label" do
    it "names the most specific place it knows" do
      location = described_class.new(status: "ok", city: "Portland", region: "Oregon", country: "United States")

      expect(location.label).to eq("Portland, Oregon, United States")
    end

    it "says so for addresses on a local network" do
      expect(described_class.new(status: "private").label).to eq("Local network")
    end

    it "returns nothing for a lookup that failed, rather than inventing a place" do
      expect(described_class.new(status: "failed", city: "Portland").label).to be_nil
    end
  end

  describe ".resolve_later" do
    it "enqueues a lookup for an address that has never been seen" do
      expect {
        described_class.resolve_later("8.8.8.8")
      }.to have_enqueued_job(ResolveIpLocationJob).with("8.8.8.8")
    end

    it "does not enqueue again while a resolved answer is still fresh" do
      described_class.create!(ip_address: "8.8.8.8", status: "ok", city: "Portland", resolved_at: 1.day.ago)

      expect {
        described_class.resolve_later("8.8.8.8")
      }.not_to have_enqueued_job(ResolveIpLocationJob)
    end

    it "enqueues again once the cached answer has gone stale" do
      described_class.create!(ip_address: "8.8.8.8", status: "ok", city: "Portland",
                              resolved_at: (described_class::TTL + 1.day).ago)

      expect {
        described_class.resolve_later("8.8.8.8")
      }.to have_enqueued_job(ResolveIpLocationJob)
    end

    it "settles a local-network address on the spot instead of queueing a lookup" do
      expect {
        described_class.resolve_later("192.168.1.20")
      }.not_to have_enqueued_job(ResolveIpLocationJob)

      expect(described_class.for_ip("192.168.1.20").status).to eq("private")
    end

    it "ignores a blank address" do
      expect { described_class.resolve_later(nil) }.not_to have_enqueued_job(ResolveIpLocationJob)
    end
  end

  describe ".lookup_map" do
    it "keys cached locations by address so a list renders in one query" do
      described_class.create!(ip_address: "8.8.8.8", status: "ok", city: "Portland", resolved_at: Time.current)

      map = described_class.lookup_map([ "8.8.8.8", "1.1.1.1", nil ])

      expect(map.keys).to eq([ "8.8.8.8" ])
      expect(map["8.8.8.8"].city).to eq("Portland")
    end
  end
end
