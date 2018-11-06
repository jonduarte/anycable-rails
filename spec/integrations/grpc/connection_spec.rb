# frozen_string_literal: true

require "spec_helper"

describe "client connection", :with_grpc_server do
  include_context "rpc stub"

  let!(:user) { User.create!(name: "john", secret: "123") }

  subject { service.connect(request) }

  context "no cookies" do
    let(:request) { AnyCable::ConnectionRequest.new }

    it "responds with error if no cookies" do
      expect(subject.status).to eq :FAILURE
    end
  end

  context "with cookies and path info" do
    let(:cookies) { "username=john" }

    let(:request) do
      AnyCable::ConnectionRequest.new(
        headers: {
          "Cookie" => cookies
        },
        path: "http://example.io/cable?token=123"
      )
    end

    it "responds with success, correct identifiers and 'welcome' message", :aggregate_failures do
      expect(subject.status).to eq :SUCCESS
      identifiers = JSON.parse(subject.identifiers)
      expect(identifiers).to include(
        "current_user",
        "url" => "http://example.io/cable?token=123"
      )
      expect(subject.transmissions.first).to eq JSON.dump("type" => "welcome")
    end

    it "logs access message (started)", log: :info do
      expect { subject }.to output(/Started \"\/cable\?token=123\" \[AnyCable\]/).to_stdout_from_any_process
    end

    context "when access logs disabled" do
      around do |ex|
        was_disabled = AnyCable.config.access_logs_disabled
        AnyCable.config.access_logs_disabled = true
        ex.run
        AnyCable.config.access_logs_disabled = was_disabled
      end

      it "doesn't log access message", log: :info do
        expect { subject }.not_to output(/Started \"\/cable\?token=123\" \[AnyCable\]/).to_stdout_from_any_process
      end
    end

    context "auth failure" do
      let(:cookies) { "user=john" }

      it "logs access message (started)", log: :info do
        expect { subject }.to output(/Started \"\/cable\?token=123\" \[AnyCable\]/).to_stdout_from_any_process
      end

      it "logs access message (rejected)", log: :info do
        expect { subject }.to output(/Finished \"\/cable\?token=123\" \[AnyCable\].*\(Rejected\)/).to_stdout_from_any_process
      end
    end
  end
end
