# encoding: UTF-8

require File.expand_path('../../test_helper', __FILE__)
require 'erb'


class SerialisationTest < MiniTest::Spec
  include Spontaneous

  def setup
    @site = setup_site
  end

  def teardown
    teardown_site
  end

  context "Content" do
    setup do
      Content.delete
      class ::Page < Spontaneous::Page
        field :title, :string, :default => "New Page"
      end

      class ::Piece < Spontaneous::Piece
        style :tepid
      end

      class ::SerialisedPage < ::Page
        field :direction, :title => "Pointing Direction", :comment => "NSEW" do
          def preprocess(value)
            ({
              "N" => "North",
              "S" => "South",
              "E" => "East",
              "W" => "West"
            })[value.upcase]
          end
        end
        field :thumbnail, :image

        style :dancing
        style :sitting
        style :kneeling

        box :insides
      end

      class ::SerialisedPiece < ::Piece
        title "Type Title"
        field :title, :string
        field :location, :string, :title => "Where", :comment => "Fill in the address"
        field :date, :date
        field :image do
          size :thumbnail do
            width 50
          end
        end

        style :freezing
        style :boiling

        box :things, :title => "My Things" do
          allow :SerialisedPage, :styles => [:sitting, :kneeling]
          field :title, :string
        end
      end


      @dancing_style = SerialisedPage.style_prototypes[:dancing].schema_id
      @sitting_style = SerialisedPage.style_prototypes[:sitting].schema_id
      @kneeling_style = SerialisedPage.style_prototypes[:kneeling].schema_id

      @freezing_style = SerialisedPiece.style_prototypes[:freezing].schema_id
      @boiling_style = SerialisedPiece.style_prototypes[:boiling].schema_id
      @tepid_style = SerialisedPiece.style_prototypes[:tepid].schema_id

      @fp = SerialisedPiece.field_prototypes

      template = ERB.new(File.read(File.expand_path('../../fixtures/serialisation/class_hash.yaml.erb', __FILE__)))
      source = File.expand_path(__FILE__)
      @class_hash = YAML.load(template.result(binding))
    end

    teardown do
      Object.send(:remove_const, :Page)
      Object.send(:remove_const, :Piece)
      Object.send(:remove_const, :SerialisedPiece)
      Object.send(:remove_const, :SerialisedPage)
    end

    context "classes" do
      should "generate a hash for JSON serialisation" do
        unless @class_hash == SerialisedPiece.export
          pp SerialisedPiece.export; puts "="*60; pp @class_hash
        end
        # SerialisedPiece.export.should == @class_hash
        assert_hashes_equal(SerialisedPiece.export, @class_hash)
      end
      should "serialise to JSON" do
        Spot::deserialise_http(SerialisedPiece.serialise_http).should == @class_hash
      end
      should "include the title field name in the serialisation of page types" do
        SerialisedPage.export(nil)[:title_field].should == 'title'
      end
      should "use JS friendly names for type keys" do
        class ::SerialisedPage
          class InnerClass < Piece
          end
        end
        Site.schema.export['SerialisedPage.InnerClass'].should ==  ::SerialisedPage::InnerClass.export
      end
    end

    context "pieces" do
      setup do

        date = "2011-07-07"
        @root = SerialisedPage.new
        @piece1 = SerialisedPiece.new
        @piece2 = SerialisedPiece.new
        @piece3 = SerialisedPiece.new
        @child = SerialisedPage.new(:slug=> "about")
        @root.insides << @piece1
        @root.insides << @piece2
        @piece1.things << @child
        @child.insides << @piece3

        @piece1.things.title = "Things title"
        @root.title = "Home"
        @root.direction = "S"
        @root.thumbnail = "/images/home.jpg"
        @root.uid = "home"


        @piece1.label = "label1"
        @piece1.title = "Piece 1"
        @piece1.location = "Piece 1 Location"
        @piece1.date = date

        @piece2.label = "label2"
        @piece2.title = "Piece 2"
        @piece2.location = "Piece 2 Location"
        @piece2.date = date

        @piece3.title = "Piece 3"
        @piece3.location = "Piece 3 Location"
        @piece3.date = date

        @child.title = "Child Page"
        @child.thumbnail = "/images/thumb.jpg"
        @child.direction = "N"
        @child.uid = "about"

        [@child, @piece1, @piece2, @piece3].each { |c| c.save; c.reload }
        @root.insides[0].style = :freezing
        @root.insides[0].visible = false
        @root.insides[1].style = :boiling
        @root.insides.first.first.style = :sitting

        @child.path.should == "/about"

        @root.save

        template = ERB.new(File.read(File.expand_path('../../fixtures/serialisation/root_hash.yaml.erb', __FILE__)))
        @root_hash = YAML.load(template.result(binding))
        @root = Content[@root.id]
      end

      should "generate a hash for JSON serialisation" do
        unless @root_hash == @root.export
          # require 'differ'
          # p Differ.diff_by_line(@root.export.to_yaml, @root_hash.to_yaml)
          puts; pp @root_hash; puts "="*60; pp @root.export
        end
        assert_hashes_equal(@root_hash, @root.export)
      end

      should "serialise to JSON" do
        # hard to test this as the serialisation order appears to change
        Spot.deserialise_http(@root.serialise_http).should == @root.export
      end

    end
  end
end
