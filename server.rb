#!/usr/bin/env ruby

require_relative "lib"
require 'jimson'
require "money-tree"

class MyHandler
  extend Jimson::Handler

  def deployContract(privkey, elf_path)
    puts privkey
    puts elf_path
    client = Client.new(privkey)
    client.deployContract(elf_path)
  end

  def getHDUserInfo(index)
    raise "index too big" if index >= 0x80000000
    seed_path = File.expand_path("~/.ckb-generator/seed_hex")
    if File.exist?(seed_path)
      seed_hex = IO.read(seed_path).strip
      master = MoneyTree::Master.new({seed_hex: seed_hex})
    else
      master = MoneyTree::Master.new
      Dir::mkdir(File.expand_path("~/.ckb-generator"))
      IO.write(File.expand_path("~/.ckb-generator/seed_hex"), master.seed_hex)
    end
    privkey = "0x" + MoneyTree::PrivateKey.new({key: master.derive_private_key(index)[0]}).to_hex
    client = Client.new(privkey)

    {
      privkey: privkey,
      pubkey: client.pubkey,
      blake160: client.blake160,
      address: client.address
    }
  end

  def getCellByTxHashIndex(tx_hash, index)
    cell_with_status = getLiveCellByTxHashIndex(tx_hash, index)
    cell_with_status.to_h
  end

  def getUserInfo(privkey)
    client = Client.new(privkey)

    {
      privkey: privkey,
      pubkey: client.pubkey,
      blake160: client.blake160,
      address: client.address
    }
  end

  def lockHash(code_hash, args, hash_type)
    CKB::Types::Script.new(
                code_hash: code_hash,
                args: args,
                hash_type: hash_type
              ).compute_hash
  end

  def queryLiveCells(lock_hash, capacity)
    puts lock_hash
    puts capacity
    i = getLiveCellsByCapacity(lock_hash, capacity)

    {
      inputs: i.inputs.map(&:to_h),
      capacity: i.capacities.to_s,
    }
  end

  def sendRawTransaction(rtx_path)
    tx_s = File.read(rtx_path).strip
    tx_json = JSON.parse(tx_s, symbolize_names: true)
    tx = CKB::Types::Transaction.from_h(tx_json)
    send_raw_transaction(tx)
  end

  def sendTransaction(privkey, tx_path)
    tx_s = File.read(tx_path).strip
    tx_json = JSON.parse(tx_s, symbolize_names: true)
    tx = CKB::Types::Transaction.from_h(tx_json)
    client = Client.new(privkey)
    client.send_transaction(tx)
  end

  def sign(privkey, tx_path)
    tx_s = File.read(tx_path).strip
    tx_json = JSON.parse(tx_s, symbolize_names: true)
    tx = CKB::Types::Transaction.from_h(tx_json)
    client = Client.new(privkey)
    stx = client.sign_transaction(tx)
    stx.witnesses
  end

  def systemScript
    system_script
  end
end

server = Jimson::Server.new(MyHandler.new)
server.start # serve with webrick on http://0.0.0.0:8999/