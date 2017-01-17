require "#{File.dirname __FILE__}/config"
require 'tmpdir'

# ホスト
MRuby::Build.new do |conf|
  toolchain :clang
  enable_debug
  enable_test
end

prev_pkg_config_path = ENV['PKG_CONFIG_PATH']

BUILD_ARCHS.each do |target, archs|
  archs.each do |arch|
    prefix = "#{BUILD_DIR}/prefixes/#{arch}"
    MRuby::CrossBuild.new arch do |conf|
      toolchain :clang
      conf.build_mrbtest_lib_only

      [conf.cc, conf.cxx, conf.objc].each do |c|
        c.command = ios_cc target, arch
        #c.defines << %w(MRB_INT64)
        c.include_paths << "#{prefix}/include"
        c.flags << ios_cflags(target, arch)
      end
      conf.linker.library_paths << %W(#{prefix}/lib #{ios_sdk target}/usr/lib)

      MRBGEMS.each do |v|
        conf.gem "#{BASE_DIR}/external/#{v}" do |spec|
          case spec.name
          when 'mruby-sqlite3'; spec.test_args = {'db_dir' => Dir.tmpdir}
          when 'mruby-cfunc'
            ENV['PKG_CONFIG_PATH'] = "#{prefix}/lib/pkgconfig:#{prev_pkg_config_path}"
            spec.use_pkg_config
          end
        end
      end

      # conf.gembox 'default'
      CORE_MRBGEMS.each{|v| conf.gem core: v }
    end
  end
end

ENV['PKG_CONFIG_PATH'] = prev_pkg_config_path
