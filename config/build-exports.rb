# 元はmobirubyのスクリプト
# "MobiRuby for iOS" is released under the MIT license

require 'nokogiri'

class BridgeMetadata
  attr_reader :consts, :enums, :structs

  def initialize(xml=nil)
    @consts, @enums, @structs = {}, {}, {}
    parse(xml) if xml
  end

  def parse(xml)
    doc = Nokogiri::XML(xml)

    doc.xpath('//struct').each do |s|
      # {.name = "CGPoint", .definition = "x:f:y:f"}
      _, name, type = /^\{([^=]+)="(.*)\}$/.match(s['type']).to_a
      type = type.gsub(/\{([^=]+)=[^}]*\}/, "{\\1}").gsub('"',':')
      @structs[name] = '    {.name="%s", .definition="%s"}' % [name.gsub(/^\w/) { |s| s.upcase }, type]
    end

    doc.xpath('//constant').each do |c|
     # @consts[c['name']] = '    {.name="%s", .type="%s", .value=(void*)&%s}' % [c['name'].gsub(/^\w/) { |s| s.upcase }, c['type'], c['name']]
      @consts[c['name']] = '    {.name="%s", .type="%s", .value=(void*)"%s"}' % [c['name'], c['type'], c['name']]
    end

    doc.xpath('//enum').each do |e|
      tt = 'u'
      val = [e['value'].to_i].pack('q')
      if /[e\.]+/.match(e['value'])
        tt = 'd'
        val = [e['value'].to_f].pack('d')
      elsif e['value'].to_i < 2^63
        tt = 's'
        val = [e['value'].to_i].pack('q')
      end
      p val
      @enums[e['name']] = %Q[    {.name="%s", .value={%s}, .type='%s'}] % [e['name'].gsub(/^\w/) { |s| s.upcase }, val.inspect, tt]
    end
  end

  def c_structs(name='structs_table', prefix='')
    %Q[
#{prefix} struct BridgeSupportStructTable #{name}[] = {
#{@structs.values.join(",\n")},
    {.name=NULL, .definition=NULL}
};
]
  end

  def c_enums(name='enums_table', prefix='')
    %Q[
#{prefix} struct BridgeSupportEnumTable #{name}[] = {
#{@enums.values.join(",\n")},
    {.name=NULL}
};
]
  end

  def c_consts(name='consts_table', prefix='')
    %Q[
#{prefix} struct BridgeSupportConstTable #{name}[] = {
#{@consts.values.join(",\n")},
    {.name=NULL}
};
]
  end
end

imports = []
metadata = BridgeMetadata.new

FRAMEWORKS.each do |fw|
  target, arch = :sim, :i386
  sdkroot = ios_sdk target
  fw_path = "#{sdkroot}/System/Library/Frameworks/#{fw}.framework"
  cflags = "-x objective-c -arch #{arch} #{ios_cflags target, arch}"

  sh %Q[CC="#{ios_cc target, arch}" ./config/gen_bridge_metadata -d --no-64-bit -f #{fw_path} -c "#{cflags}" -o #{BUILD_DIR}/cocoa_bridgesupport.xml]

  imports += Dir.glob(File.join(fw_path, 'Headers', '*.h')).map do |header|
    header.gsub(File.join(sdkroot, fw_path, 'Headers'), fw.gsub('.framework', ''))
  end

  metadata.parse File.read "#{BUILD_DIR}/cocoa_bridgesupport.xml"
end


open(COCOA_BRIDGESUPPORT_C, 'w').puts <<__STR__
/*
 Do not change this file.
 Generated from BridgeSupport.
*/
#include "cocoa.h"
#include "mruby/value.h"
#include <dlfcn.h>

#{imports.uniq.map{|i| "#import \"#{i}\""}.join("\n")}


#{metadata.c_structs(:structs_table, :static)}

#{metadata.c_enums(:enums_table, :static)}

#{metadata.c_consts(:consts_table, :static)}

void
init_cocoa_bridgesupport(mrb_state *mrb)
{
    void *dlh = dlopen(NULL, RTLD_LAZY);
    struct BridgeSupportConstTable *ccur = consts_table;
    while(ccur->name) {
        if(ccur->name == ccur->value) {
            ccur->value = dlsym(dlh, (const char*)ccur->value);
        }
        ++ccur;
    }
    dlclose(dlh);
    load_cocoa_bridgesupport(mrb, structs_table, consts_table, enums_table);
}

__STR__
