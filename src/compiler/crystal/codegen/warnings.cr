module Crystal
  struct DeprecatedAnnotation
    getter message : String?

    def initialize(@message = nil)
    end

    def self.from(ann : Annotation)
      args = ann.args
      named_args = ann.named_args

      if named_args
        ann.raise "too many named arguments (given #{named_args.size}, expected maximum 0)"
      end

      message = nil
      count = 0

      args.each do |arg|
        case count
        when 0
          arg.raise "first argument must be a String" unless arg.is_a?(StringLiteral)
          message = arg.value
        else
          ann.wrong_number_of "deprecated annotation arguments", args.size, "1"
        end

        count += 1
      end

      new(message)
    end
  end

  class Def
    def short_reference
      case owner
      when Program
        "top-level #{name}"
      when .metaclass?
        "#{owner.instance_type}.#{name}"
      else
        "#{owner}##{name}"
      end
    end
  end

  class CodeGenVisitor
    def check_call_to_deprecated_method(node : Call)
      return unless @program.warnings.all?

      if (ann = node.target_def.annotation(@program.deprecated_annotation)) &&
         (deprecated_annotation = DeprecatedAnnotation.from(ann))
        return if ignore_warning_due_to_location(node.location)

        message = deprecated_annotation.message
        message = message ? " #{message}" : ""

        full_message = node.warning "Deprecated #{node.target_def.short_reference}.#{message}"

        @program.warning_failures << full_message
      end
    end

    private def ignore_warning_due_to_location(location : Location?)
      return false unless location

      filename = location.original_filename
      return false unless filename

      return @program.warnings_exclude.any? do |path|
        filename.starts_with?(path)
      end
    end
  end

  class Command
    def report_warnings(result : Compiler::Result)
      return if result.program.warning_failures.empty?

      result.program.warning_failures.each do |message|
        STDERR.puts message
      end
      STDERR.puts "A total of #{result.program.warning_failures.size} warnings were found."
    end

    def warnings_fail_on_exit?(result : Compiler::Result)
      result.program.error_on_warnings && result.program.warning_failures.size > 0
    end
  end
end
