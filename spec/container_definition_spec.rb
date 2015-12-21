require 'spec_helper'

module Cur
  describe ContainerDefinition do
    let(:container) { ContainerDefinition.new }
    let(:parent) { ContainerDefinition.new }

    before do
      container.parent = parent
    end

    describe "#valid?" do
      it "should return false if there is no name" do
        expect(container.valid?).to be false
      end

      it "should return false if there is no image" do
        container.instance_variable_set(:@image, nil)
        expect(container.valid?).to be false
      end

      it "should return true if the name and image are present" do
        container.name "name"
        container.image "image"
        expect(container.valid?).to be true
      end
    end

    describe "#validate!" do
      it "should raise an exception if there is no name" do
        container.image "image"
        expect{container.validate!}.to raise_error
      end

      it "should raise an exception if there is no image" do
        container.name "name"
        expect{container.validate!}.to raise_error
      end
    end

    describe "attributes" do
      before do
        parent.name "parent"
        parent.command "/bin/echo foo"
        parent.image "parent_image"
        parent.env 'bar' => 'baz'
        parent.links 'other' => 'other'
        parent.expose 80 => 8080
        parent.volumes "parent" => "/usr/local/src/parent"
        parent.workdir "parent"
        parent.detach false
        parent.rm false

        container.name "name"
        container.command "/bin/bash"
        container.image "image"
        container.env 'foo' => 'bar'
        container.links 'parent' => 'parent'
        container.expose 443 => 443
        container.volumes "." => "/usr/local/src"
        container.workdir "."
        container.detach true
        container.rm true
      end

      describe "#name" do
        it "should return the name value with no argument passed" do
          parent.instance_variable_set(:@name, nil)
          expect(container.name).to eq("name")
        end

        it "should allow specification of the name value with an argument passed" do
          container.name "foo"
          expect(container.name).to eq("parent.foo")
        end

        it "should result in pathed name if there is a parent container" do
          parent = ContainerDefinition.new
          container.parent = parent
          parent.name "first"
          expect(container.name).to eq("first.name")
        end
      end

      describe "#command" do
        it "should return the command value with no argument passed" do
          expect(container.command).to eq("/bin/bash")
        end

        it "should allow specification of the command value with an argument passed" do
          container.command "/bin/echo test"
          expect(container.command).to eq("/bin/echo test")
        end

        it "should inherit command from parent if not specified" do
          container.instance_variable_set(:@command, nil)
          expect(container.command).to eq("/bin/echo foo")
        end
      end

      describe "#image" do
        it "should return the image value with no argument passed" do
          expect(container.image).to eq("image")
        end

        it "should allow specification of the image value with an argument passed" do
          container.image "foo"
          expect(container.image).to eq("foo")
        end

        it "should inherit image from parent if not specified" do
          container.instance_variable_set(:@image, nil)
          expect(container.image).to eq("parent_image")
        end
      end

      describe "#env" do
        it "should return the environment variable value with no value passed" do
          expect(container.env('foo')).to eq('bar')
        end

        it "should allow specification of multiple env variables in single call" do
          container.env :a => "a", :b => "b"
          expect(container.env(:a)).to eq("a")
          expect(container.env(:b)).to eq("b")
        end

        it "should convert values to strings" do
          container.env :a => 1
          expect(container.env(:a)).to eq("1")
        end

        it "should inherit the env variables of parent containers" do
          expect(container.env('bar')).to eq('baz')
        end
      end

      describe "#links" do
        it "should return the links variable value with no value passed" do
          expect(container.links('parent')).to eq('parent')
        end

        it "should allow specification of multiple links in single call" do
          container.links 'container3' => 'c3', 'container4' => 'c4'
          expect(container.links('container3')).to eq('c3')
          expect(container.links('container4')).to eq('c4')
        end

        it "should convert values to strings" do
          container.links :container3 => :c3
          expect(container.links('container3')).to eql('c3')
        end

        it "should inherit the links of parent containers" do
          expect(container.links('other')).to eq('other')
        end
      end

      describe "#expose" do
        it "should return the container port value with no such value passed" do
          expect(container.expose("443")).to eql("443")
        end

        it "should allow specification of multiple ports to expose" do
          container.expose 80 => 80, 443 => 443
          expect(container.expose("80")).to eql("80")
          expect(container.expose("443")).to eql("443")
        end

        it "should not inherit exposed ports from parent containers" do
          expect(container.expose("80")).to be_nil
        end
      end

      describe "#volumes" do
        it "should return the directory on the container filesystem to mount to with no value passed" do
          expect(container.volumes(".")).to eql("/usr/local/src")
        end

        it "should inherit the volumes of parent containers" do
          expect(container.volumes('parent')).to eql('/usr/local/src/parent')
        end
      end

      describe "#workdir" do
        it "should return the workdir value with no argument passed" do
          expect(container.workdir).to eq(".")
        end

        it "should allow specification of the workdir value with an argument passed" do
          container.workdir File.expand_path("~")
          expect(container.workdir).to eq(File.expand_path("~"))
        end

        it "should inherit value from parent if not specified" do
          container.instance_variable_set(:@workdir, nil)
          expect(container.workdir).to eq("parent")
        end
      end

      describe "#detach" do
        it "should return the detach value with no argument passed" do
          expect(container.detach).to be true
        end

        it "should allow specification of the detach value with an argument passed" do
          container.detach false
          expect(container.detach).to be false
        end

        it "should inherit value from parent if not specified" do
          container.instance_variable_set(:@detach, nil)
          expect(container.detach).to eq(parent.detach)
        end
      end

      describe "#rm" do
        it "should return the rm value with no argument passed" do
          expect(container.rm).to eq(true)
        end

        it "should allow specification of the rm value with an argument passed" do
          container.rm false
          expect(container.rm).to eq(false)
        end

        it "should inherit value from parent if not specified" do
          container.instance_variable_set(:@rm, nil)
          expect(container.rm).to eq(parent.rm)
        end
      end
    end
  end
end
