# encoding: utf-8
require 'logstash/filters/base'
require 'logstash/namespace'

class LogStash::Filters::Rmf < LogStash::Filters::Base

  config_name 'rmf'

  config :whitelist, :validate => :array
  

  public
  def register
    # set whitelist to an array of arrays each element of those are field
    # for example if we had ["a.a.a", "[b][c]"] we'll have [["a","a","a"]["b","c"]]
    @whitelist.map! {
        |item| item.include?('[') ? item.split('][') : item.split('.')
    }
    @whitelist.each_with_index do |item, i|
      if item.kind_of?(Array)
        if item[0].include? '['
          item[0]=item[0][1..-1]
        end
        if item[-1].include? ']'
          item[-1]=item[-1][0..-2]
        end
        item.each_with_index do |ele, j|
          if ele.include?('(')
            ele[1..-2].split('|').each do |el|
              if @whitelist[i].length >= j+1
                @whitelist += [@whitelist[i][0..j-1] + [el] + @whitelist[i][j+1..-1]]
              else
                @whitelist += [@whitelist[i][0..j-1] + [el]]
              end
            end
            @whitelist.delete(item)
          end
        end
      end
    end
  end

  private
  def iterate(event, hash, level, path)
    hash.each do |k,v|
      if k[0] == '@' || k[0] == '_'
        next
      end
      tmp_path = path.clone + [k]
      contains = -1
      @whitelist.each_with_index do |allowed, j|
        if k == allowed[level]
          (level).downto(0).each do |i|
            if tmp_path[i] == allowed[i]
              contains = j
            end
          end
          break
        end
      end
      if contains != -1
        if v.is_a?(::Hash)
          if level == @whitelist[contains].length-1
            next
          else
            iterate(event, v, level+1, tmp_path)
          end
        end
      else
        tmp_path.map! {|item| '[' + item + ']'}
        tmp = ''
        tmp_path.each do |str|
          tmp += str
        end
        event.remove(tmp)
      end
    end
  end

  public
  def filter(event)
    iterate(event, event.to_hash, 0, [])
    # filter_matched should go in the last line of our successful code
    filter_matched(event)
  end
end
