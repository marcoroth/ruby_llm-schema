# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Schema, "conditional properties" do
  let(:schema_class) { Class.new(described_class) }

  it "supports require_if with a single condition" do
    schema_class.string :video_provider
    schema_class.string :published_at, required: false

    schema_class.require_if :video_provider, equals: "youtube" do
      requires :published_at
    end

    expect(schema_class.conditions.length).to eq(1)
    expect(schema_class.conditions.first).to eq({
      if: {
        properties: {"video_provider" => {const: "youtube"}},
        required: ["video_provider"]
      },
      then: {
        required: ["published_at"]
      }
    })
  end

  it "supports validates with not_value and min_length" do
    schema_class.string :video_provider
    schema_class.string :published_at, required: false

    schema_class.require_if :video_provider, equals: "youtube" do
      requires :published_at
      validates :published_at, not_value: "TODO", min_length: 1
    end

    then_schema = schema_class.conditions.first[:then]

    expect(then_schema[:required]).to eq(["published_at"])
    expect(then_schema[:properties]).to eq({
      "published_at" => {type: "string", not: {const: "TODO"}, minLength: 1}
    })
  end

  it "includes single condition as if/then in JSON schema" do
    schema_class.string :video_provider
    schema_class.string :published_at, required: false

    schema_class.require_if :video_provider, equals: "youtube" do
      requires :published_at
    end

    json = schema_class.new.to_json_schema
    schema = json[:schema]

    expect(schema[:if]).to eq({
      properties: {"video_provider" => {const: "youtube"}},
      required: ["video_provider"]
    })

    expect(schema[:then]).to eq({
      required: ["published_at"]
    })
  end

  it "wraps multiple conditions in allOf" do
    schema_class.string :video_provider
    schema_class.string :published_at, required: false
    schema_class.string :video_id, required: false

    schema_class.require_if :video_provider, equals: "youtube" do
      requires :published_at
    end

    schema_class.require_if :video_provider, equals: "vimeo" do
      requires :video_id
    end

    json = schema_class.new.to_json_schema
    schema = json[:schema]

    expect(schema).not_to have_key(:if)
    expect(schema[:allOf].length).to eq(2)
    expect(schema[:allOf][0][:if][:properties]["video_provider"][:const]).to eq("youtube")
    expect(schema[:allOf][1][:if][:properties]["video_provider"][:const]).to eq("vimeo")
  end

  it "does not include conditions when none are defined" do
    schema_class.string :name

    json = schema_class.new.to_json_schema
    schema = json[:schema]

    expect(schema).not_to have_key(:if)
    expect(schema).not_to have_key(:then)
    expect(schema).not_to have_key(:allOf)
  end

  it "supports multiple requires in a single condition" do
    schema_class.string :video_provider
    schema_class.string :published_at, required: false
    schema_class.string :video_id, required: false

    schema_class.require_if :video_provider, equals: "youtube" do
      requires :published_at, :video_id
    end

    then_schema = schema_class.conditions.first[:then]

    expect(then_schema[:required]).to eq(["published_at", "video_id"])
  end

  it "propagates conditions through nested schema via of:" do
    sub_schema = Class.new(described_class) do
      string :video_provider, required: true
      string :published_at, required: false

      require_if :video_provider, equals: "youtube" do
        requires :published_at
      end
    end

    parent_schema = Class.new(described_class) do
      array :talks, of: sub_schema, required: false
    end

    json = parent_schema.new.to_json_schema
    talks_items = json[:schema][:properties][:talks][:items]

    expect(talks_items[:if]).to eq({
      properties: {"video_provider" => {const: "youtube"}},
      required: ["video_provider"]
    })

    expect(talks_items[:then]).to eq({
      required: ["published_at"]
    })
  end

  it "supports validates with pattern" do
    schema_class.string :video_provider
    schema_class.string :published_at, required: false

    schema_class.require_if :video_provider, equals: "youtube" do
      requires :published_at
      validates :published_at, not_value: "TODO", min_length: 1, pattern: "^\\d{4}-\\d{2}-\\d{2}"
    end

    then_schema = schema_class.conditions.first[:then]

    expect(then_schema[:properties]["published_at"]).to eq({
      type: "string",
      not: {const: "TODO"},
      minLength: 1,
      pattern: "^\\d{4}-\\d{2}-\\d{2}"
    })
  end
end
