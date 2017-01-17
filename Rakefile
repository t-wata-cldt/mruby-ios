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
['libuv',  'libffi'].each do |lib|
  BUILD_ARCHS.each do |target, archs|
    archs.each do |arch|
      file "#{BUILD_DIR}/#{lib}/#{arch}/.libs/#{lib}.a" => "external/#{lib}" do |t|
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

rule(/\.o$/ => [proc {|n| n.sub(/\.o$/, '.c') }]) do |t|
  frameworks_dir = "#{ios_sdk target}/System/Library/Frameworks"
  frameworks = FRAMEWORKS.map{|v| "-framework #{v}" }
  sh "#{ios_cc target, arch} #{ios_cflags target, arch} #{t.source} -c -o #{t.name} \
-F#{frameworks_dir} #{frameworks}"
end

directory APP_PATH
file APP_PATH => [LIBMRUBY] do
end

desc 'アプリ生成'
task :all => APP_PATH

# デフォルトはallに
task :default => :all

desc 'シミュレータで実行'
task :sim

desc '実機にインストール'
task :deploy
