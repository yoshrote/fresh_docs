# typed: false
# frozen_string_literal: true
require('yard')
require('fresh_docs/sord/type_converter')

PASS_WITH_NO_SORBET_SIG = true

module FreshDocs
  class YardCheck
    def convert_sorbet_to_yard(sig)
      if sig.is_a?(T::Types::TypedArray)
        "Array<#{convert_sorbet_to_yard(sig.type)}>"
      elsif sig.is_a?(T::Types::Union)
        sig.types.map { |x| convert_sorbet_to_yard(x) } .join(", ")
      elsif sig.is_a?(T::Types::Simple)
        if sig.raw_type.eql?(NilClass)
          return "nil"
        end
        sig.raw_type.to_s
      elsif sig.is_a?(T::Types::TypedHash)
        "Hash<#{convert_sorbet_to_yard(sig.keys)},#{convert_sorbet_to_yard(sig.values)}>"
      elsif sig.is_a?(T::Private::Types::Void)
        "void"
      elsif sig.eql?(T.untyped)
        "untyped"
      else
        puts sig.inspect
        raise "Unknown thing #{sig}"
      end
    end

    def compare(ssig, ysig)
      return false if ysig.nil?

      y_to_s = Sord::TypeConverter.yard_to_sorbet(ysig.types)
      if ssig.is_a?(T::Private::Types::Void)
        return y_to_s.eql?("void")
      end
      y_to_s.to_s.eql?(ssig.to_s)
    end

    def sorbet_equal_yard(sig, obj)
      # bail if there is no sorbet
      return PASS_WITH_NO_SORBET_SIG if sig.nil?

      sorbet_params = Hash[sig.arg_types].merge(sig.kwarg_types)
      yard_params = Hash[obj.tags
        .select { |x| x.tag_name == "param" }
        .map { |x| [x.name.to_sym, x] }
      ]
      sorbet_returns = sig.return_type
      yard_returns = obj.tags.select { |x| x.tag_name == "return" } .first
      unless compare(sorbet_returns, yard_returns)
        puts "[DEBUG] returns mismatch"
        return false
      end
      unless sorbet_params.keys.eql?(yard_params.keys)
        puts "[DEBUG] keys mismatch"
        return false
      end
      unless sorbet_params.map do |skey, ssig|
               compare(ssig, yard_params[skey])
             end.all?
        puts "[DEBUG] params mismatch"
        return false
      end
      true
    end

    def run(root)
      total = Set.new
      failed = Set.new
      failed_location = Hash.new { |hash, key| hash[key] = Set.new }
      Dir.glob("#{root}/**/*.rb") do |filepath|
        YARD.parse(filepath)
        YARD::Registry.all.map do |object|
          next unless object.is_a?(YARD::CodeObjects::MethodObject)
          next if object.visibility == :private
          next if total.include?(object)

          actual_method = nil
          begin
            actual_method = Kernel.const_get(object.namespace.to_s).instance_method(object.name.to_sym)
          rescue
            actual_method = Kernel.const_get(object.namespace.to_s).singleton_method(object.name.to_sym)
          end
          total << object
          sorbet_sig = T::Private::Methods.signature_for_method(actual_method)
          next if sorbet_equal_yard(sorbet_sig, object)
          failed << object
          failed_location[object.file] << object
          puts "++++++++++++++"
          puts object.title
          puts "YARD meta"
          object.tags.each do |node|
            if node.tag_name == "return"
              puts "return #{node.types.join(', ')}"
            elsif node.tag_name == "param"
              puts "#{node.name}: #{node.types.join(', ')}"
            end
          end
          unless sorbet_sig.nil?
            puts "--------------"
            puts "Sorbet meta"
            sorbet_params = Hash[sorbet_sig.arg_types].merge(sorbet_sig.kwarg_types)
            sorbet_params.each do |param, psig|
              puts "#{param}: #{convert_sorbet_to_yard(psig)}"
            end
            puts "return #{convert_sorbet_to_yard(sorbet_sig.return_type)}"
          end
          puts "++++++++++++++"
        end
      end
      puts "Total: #{total.size}; Failed: #{failed.size}"
      failed_location.sort_by { |_k, v| -v.size }.each do |key, value|
        puts "#{key}: #{value.size}"
      end
    end
  end
end
