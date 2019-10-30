#!/usr/bin/env ruby

require_relative "lib"
require "sqlite3"

class Sync
  attr_reader :db
  attr_reader :tip_height

  def initialize()
    # Open database
    @db = SQLite3::Database.new('./sync.db')
    # Create tables
    db.execute "CREATE TABLE IF NOT EXISTS info(tip_height INT)"
    db.execute "CREATE TABLE IF NOT EXISTS livecells(tx_hash varchar(66),
                                                     cell_index int,
                                                     capacity int,
                                                     lock_code_hash varchar(66),
                                                     lock_args text,
                                                     lock_hash_type varchar(7),
                                                     type_code_hash varchar(66),
                                                     type_args text,
                                                     type_hash_type varchar(7),
                                                     height int)"
    tip_height = db.get_first_value("SELECT * from info")
    if !tip_height
      puts "init tip_height"
      tip_height = 1
      db.execute "INSERT INTO info (tip_height) VALUES (?)", tip_height
    end
    @tip_height = tip_height
  end

  def update_tip_height()
    db.execute "UPDATE info set tip_height=?", tip_height
  end

  def insert_live_cells(live_cells)
    live_cells.each do |cell|
      db.execute "INSERT INTO livecells (tx_hash,
                                         cell_index,
                                         capacity,
                                         lock_code_hash,
                                         lock_args,
                                         lock_hash_type,
                                         type_code_hash,
                                         type_args,
                                         type_hash_type,
                                         height) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                                         cell.tx_hash,
                                         cell.cell_index,
                                         cell.capacity,
                                         cell.lock_code_hash,
                                         cell.lock_args,
                                         cell.lock_hash_type,
                                         cell.type_code_hash,
                                         cell.type_args,
                                         cell.type_hash_type,
                                         cell.height
    end
  end

  def del_live_cells(dead_cells)
    dead_cells.each do |cell|
      db.execute "DELETE from livecells where tx_hash=? AND cell_index=?", cell.tx_hash, cell.cell_index
    end
  end

  def sync
    while true
      puts Time.now
      puts "start sync..."
      new_tip_height = get_tip_block_number()
      puts "tip_height on chain", new_tip_height
      from = tip_height
      if new_tip_height > 13
        to = new_tip_height - 12
      else
        to = 1
      end
      while from < to
        (0..[100, to - from].min).each do
          cells = sync_cells(from)
          del_live_cells(cells.dead_cells)
          insert_live_cells(cells.live_cells)
          from += 1
        end
        @tip_height = from
        update_tip_height()
        puts Time.now
        puts "sync to height", tip_height
      end
      sleep 10
    end
  end

  def close
    if db
      db.close
    end
  end
end
