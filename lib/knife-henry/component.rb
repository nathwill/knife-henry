require 'knife-henry'
require 'safe_yaml'

module KnifeHenry
  class Component
    attr_accessor :name, :berks, :role, :recipe, :vars,
                  :attributes, :templates, :tests

    Template = Struct.new(:name, :content)

    def initialize (opts = {})
      validate!(opts)
      @name = opts['name']
      @berks = opts['berks']
      @role = opts['role']
      @recipe = opts['recipe']
      @vars = opts['vars'] || {}
      @attributes = opts['attributes']
      @templates = Array.new
      opts['templates'] = Array.new unless opts['templates'].is_a? Array
      opts['templates'].each do |template|
        @templates << build_template(template)
      end
    end

    def render (context = {})
      validate_context!(context)
      render_role(context[:repo], context[:cookbook]) if self.role
      render_recipe(context[:repo], context[:cookbook]) if self.recipe
      render_attributes(context[:repo], context[:cookbook]) if self.attributes
      self.templates.each do |template|
        render_template(template, context)
      end
    end

    def save
      user_lib = KnifeHenry.const_get(:USER_LIB)
      f = File.join(user_lib, "resources", "components", "#{self.name}.yml")
      File.open(f, 'w') { |file|
        file.write(self.to_yaml)
      }
    end

    private
    def validate! (opts)
      unless opts['name']
        raise ArgumentError, "Missing required parameter 'name'for component."
      end
    end

    def validate_context! (context)
      repo = File.expand_path(context[:repo])
      cookbook = File.join(repo, "site-cookbooks", context[:cookbook])
      if !Dir.exist?(repo)
        raise ArgumentError, "Repo not found: #{context[:repo]}"
      elsif !Dir.exist?(cookbook)
        raise ArgumentError, "Site cookbook not found: #{context[:cookbook]}"
      end
    end

    def build_template (template = {})
      name, content = template.first
      Template.new(name, content)
    end

    def render_recipe (repo, cookbook)
      repo = File.expand_path(repo)
      path = File.join(repo, "site-cookbooks", cookbook)
      File.open(File.join(path, "recipes", "#{self.name}.rb"), 'w') { |recipe|
        recipe.write(self.recipe)
      }
    end

    def render_role (repo, cookbook)
      path = File.expand_path(repo)
      template = Erubis::Eruby.new(self.role)
      File.open(File.join(path, "roles", "#{self.name}.rb"), 'w') { |role|
        role.write( template.evaluate({ :cookbook => cookbook,
                                        :vars     => self.vars}) )
      }
    end

    def render_attributes (repo, cookbook)
      path = File.expand_path(File.join(repo,"site-cookbooks", cookbook))
      File.open(File.join(path, "attributes", "default.rb"), 'a') { |attr|
        attr.write(self.attributes)
      }
    end

    def render_template (template, context)
      repo = File.expand_path(context[:repo])
      path = File.join(repo, "site-cookbooks", context[:cookbook])
      out = File.join(path, "templates", "default", template.name)
      File.open(out, 'w') { |t|
        t.write(template.content)
      }
    end
  end
end
