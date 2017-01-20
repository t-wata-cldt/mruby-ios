# ひとまずこのRakefileと同じ場所にchdir
Dir.chdir File.dirname __FILE__

require 'open-uri'
require 'fileutils'
require './config/config'

# 外部ライブラリ置き場
directory 'external'

[
  ['mruby', 'mruby/mruby', MRUBY_VERSION],
  ['mruby-cfunc', 't-wata-cldt/mruby-cfunc', 'fix_for_latest_2015_05_29'],
  ['mruby-json', 'mattn/mruby-json', :master],
  ['mruby-sqlite3', 'mattn/mruby-sqlite3', :master],
  ['mruby-uv', 'mattn/mruby-uv', :master],
  ['mruby-http', 'mattn/mruby-http', :master],
  ['mruby-digest', 'iij/mruby-digest', :master],
  ['mruby-pack', 'iij/mruby-pack', :master],
  ['ios-sim', 'phonegap/ios-deploy', IOS_SIM_VERSION],
  ['ios-deploy', 'phonegap/ios-deploy', IOS_DEPLOY_VERSION],
  ['libffi', 'libffi/libffi', LIBFFI_VERSION],
].each do |name, url, version|
  directory "external/#{name}"
  file "external/#{name}" do
    Dir.chdir 'external' do
      opt = ''
      opt << ' --depth=1' if version == :master
      sh "git clone #{opt} 'git@github.com:#{url}.git' '#{name}'"
      Dir.chdir name do
        sh "git checkout #{version}"
        print "#{name} version: #{version}\n"
      end
    end
  end

  file LIBMRUBY => "external/#{name}" if name =~ /^mruby-/
end


# ひとまずカスタム版を使う
directory 'external/mruby-cocoa'
task 'external/mruby-cocoa' do
  fail 'mruby-cocoa not found'
end

file "external/libuv-v#{LIBUV_VERSION}.tar.gz" do |t|
  puts "Downloading libuv tarball... (#{LIBUV_VERSION})"
  open "http://dist.libuv.org/dist/v#{LIBUV_VERSION}/libuv-v#{LIBUV_VERSION}.tar.gz" do |f|
    File.write t.name, f.read
  end
end

file 'external/libuv' => "external/libuv-v#{LIBUV_VERSION}.tar.gz" do |t|
  puts "Extracting libuv tarball... (#{LIBUV_VERSION})"
  Dir.chdir 'external' do
    sh "tar xf libuv-v#{LIBUV_VERSION}.tar.gz"
    FileUtils.mv "libuv-v#{LIBUV_VERSION}", 'libuv'
  end

  Dir.chdir(t.name) { sh './autogen.sh' }
end

file 'external/libffi' do |t|
  Dir.chdir(t.name) { sh './autogen.sh' }
end

# ビルドしたファイルの出力先
directory BUILD_DIR

BUILD_ARCHS.values.flatten.each do |arch|
  directory "#{BUILD_DIR}/prefixes/#{arch}"
end

# configureでクロスビルドしてユニバーサルライブラリ生成
STATIC_LIBS.each do |lib|
  BUILD_ARCHS.each do |target, archs|
    archs.each do |arch|
      file "#{BUILD_DIR}/#{lib}/#{arch}/.libs/#{lib}.a" => "external/#{lib}" do |t|
        # __clear_cacheがundefinedになるので
        patching_file = "external/libffi/src/arm/ffi.c"
        if lib == 'libffi' && File.read(patching_file) !~ /sys_icache_invalidate/
          File.write patching_file, <<EOS
#include <stddef.h>
void sys_icache_invalidate(void *start, size_t len);
#define __clear_cache(start, end) sys_icache_invalidate(start, (char *)end-(char *)start)

#{File.read patching_file}
EOS
        end

        d = "#{BUILD_DIR}/#{lib}/#{arch}"
        FileUtils.mkdir_p d
        Dir.chdir d do
          sh "CC='#{ios_cc target, arch}' CFLAGS='#{ios_cflags target, arch}' \
CPP='#{ios_cc target, arch} -E' CPPFLAGS='#{ios_cflags target, arch}' \
CXX='#{ios_cxx target, arch}' CXXFLAGS='#{ios_cflags target, arch}' \
CXXCPP='#{ios_cxx target, arch} -E' CXXCPPFLAGS='#{ios_cflags target, arch}' \
#{BASE_DIR}/external/#{lib}/configure \
--prefix=#{BUILD_DIR}/prefixes/#{arch} \
--host=#{to_host_arch arch}-iphone-darwin \
--enable-static --disable-shared"
          sh "make -j #{BUILD_TASKS}"
          sh "make -j #{BUILD_TASKS} install"
        end
      end
    end
  end

  libs = BUILD_ARCHS.values.flatten.map{|v| "#{BUILD_DIR}/#{lib}/#{v}/.libs/#{lib}.a" }
  file "#{BUILD_DIR}/#{lib}.a" => libs do |t|
    FileUtils.rm_f t.name
    sh "lipo -create #{t.prerequisites.join ' '} -output #{t.name}"
  end

  file LIBMRUBY => "#{BUILD_DIR}/#{lib}.a"
end

file LIBMRUBY => 'config/mruby_config.rb' do |t|
  Dir.chdir 'external/mruby' do
    sh "MRUBY_CONFIG='#{MRUBY_CONFIG}' \
MRUBY_BUILD_DIR='#{MRUBY_BUILD_DIR}' ./minirake all"
  end

  libs = BUILD_ARCHS.values.flatten.map{|v| "#{BUILD_DIR}/mruby/#{v}/lib/libmruby.a" }
  sh "lipo -create #{libs.join ' '} -output #{t.name}"
end

file MRBC_EXEC => LIBMRUBY

file "#{BUILD_DIR}/main_script.rb.c" => [Dir.glob("external/mobiruby-ios/src/*.rb"), MRBC_EXEC].flatten do |t|
  sh "#{MRBC_EXEC} -Bmrb_main_irep -o #{t.name} external/mobiruby-ios/src/*.rb"
end

file "#{BUILD_DIR}/cocoa_bridgesupport.c" => "config/build-exports.rb" do |t|
  load "#{BASE_DIR}/config/build-exports.rb"
end

BUILD_ARCHS.each do |target, archs|
  archs.each do |arch|
    directory "#{BUILD_DIR}/#{arch}"

    frameworks_dir = "#{ios_sdk target}/System/Library/Frameworks"
    frameworks = FRAMEWORKS.map{|v| "-framework #{v}" }.join ' '
    include_dirs = ["#{BASE_DIR}/external/mobiruby-ios/include"].map{|v| "-I#{v}"}.join ' '

    compile_c_src = Proc.new do |obj, src, build_exec = false|
      FileUtils.mkdir_p File.dirname obj
      src = src.join ' ' if src.kind_of? Array
      if build_exec
        extra_flags = "-lsqlite3" # sqlite3は動的ライブラリ
      else
        extra_flags = "-c" # オブジェクトファイルを作成
      end
      sh "#{ios_cc target, arch} #{ios_cflags target, arch} -o #{obj} #{extra_flags} \
-F#{frameworks_dir} #{frameworks} \
#{include_dirs} \
#{src}"
    end

    rule(/\.o$/ => "%{^#{BUILD_DIR}/#{arch},#{BASE_DIR}}X.c") do |t|
      compile_c_src.call t.name, t.source
    end
    rule('.o' => "%{^#{BUILD_DIR}/#{arch},#{BUILD_DIR}}X.c") do |t|
      compile_c_src.call t.name, t.source
    end
    rule(/\.o$/ => "%{^#{BUILD_DIR}/#{arch},#{BASE_DIR}}X.m") do |t|
      compile_c_src.call t.name, t.source
    end

    main_obj = "#{BUILD_DIR}/#{arch}/external/mobiruby-ios/mobiruby-ios/main.o"
    file "#{BUILD_DIR}/#{arch}/#{APP_NAME}" => [LIBMRUBY,
                                                "#{BUILD_DIR}/#{arch}/main_script.rb.o",
                                                "#{BUILD_DIR}/#{arch}/cocoa_bridgesupport.o",
                                                main_obj,
                                                *STATIC_LIBS.map{|v| "#{BUILD_DIR}/#{v}.a" }] do |t|
      compile_c_src.call t.name, t.prerequisites, true
    end
  end
end

execs = BUILD_ARCHS.values.flatten.map{|v| "#{BUILD_DIR}/#{v}/#{APP_NAME}" }
file "#{APP_PATH}/#{APP_NAME}" => execs do |t|
  FileUtils.mkdir_p File.dirname t.name
  sh "lipo -create #{execs.join ' '} -output #{t.name}"
end

directory APP_PATH
file APP_PATH => ["#{APP_PATH}/#{APP_NAME}",
                  'external/mobiruby-ios/icon.png',
                  'external/mobiruby-ios/icon@2x.png'] do
  FileUtils.cp 'external/mobiruby-ios/icon.png', "#{APP_PATH}/icon.png"
  FileUtils.cp 'external/mobiruby-ios/icon@2x.png', "#{APP_PATH}/icon@2x.png"

  File.write "#{APP_PATH}/Info.plist", <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>#{LANGUAGE}</string>
	<key>CFBundleDisplayName</key>
	<string>#{APP_NAME}</string>
	<key>CFBundleExecutable</key>
	<string>#{APP_NAME}</string>
	<key>CFBundleIcons</key>
	<dict>
		<key>CFBundlePrimaryIcon</key>
		<dict>
			<key>CFBundleIconFiles</key>
			<array>
				<string>icon.png</string>
				<string>icon@2x.png</string>
			</array>
		</dict>
	</dict>
	<key>CFBundleIdentifier</key>
	<string>#{PRODUCT_BUNDLE_IDENTIFIER}</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>${PRODUCT_NAME}</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>CFBundleVersion</key>
	<string>1.0</string>
	<key>LSRequiresIPhoneOS</key>
	<true/>
	<key>UIRequiredDeviceCapabilities</key>
	<array>
		<string>armv7</string>
	</array>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
	<key>UISupportedInterfaceOrientations~ipad</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
	</array>
</dict>
</plist>
EOF
end

desc 'アプリ生成'
task :all => APP_PATH

# デフォルトはallに
task :default => :all

desc 'シミュレータで実行'
task :sim

desc '実機にインストール'
task :deploy
