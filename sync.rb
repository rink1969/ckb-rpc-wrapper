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
    db.execute "CREATE TABLE IF NOT EXISTS livecells(tx_hash varchar(66), cell_index int, capacity int, height int)"
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
      db.execute "INSERT INTO livecells (tx_hash, cell_index, capacity, height) VALUES (?, ?, ?, ?)", cell.tx_hash, cell.cell_index, cell.capacity, cell.height
    end
  end

  def del_live_cells(dead_cells)
    dead_cells.each do |cell|
      db.execute "DELETE from livecells where tx_hash=? AND cell_index=?", cell.tx_hash, cell.cell_index
    end
  end

  def sync
    while true
      sleep 10
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
        cells = sync_cells(from)
        del_live_cells(cells.dead_cells)
        insert_live_cells(cells.live_cells)
        from += 1
      end
      @tip_height = from
      update_tip_height()
      puts "stop sync at height", tip_height
    end
  end

  def close
    if db
      db.close
    end
  end
end
