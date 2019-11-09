require 'rubygems'
require 'bundler/setup'
require "ckb"

MIN_FEE = 1000 * 2048

def sync_cells(height)
  api = CKB::API.new
  live_cells = []
  dead_cells = []
  block = api.get_block_by_number(height)
  block.transactions.each do |tx|
    tx.inputs.each do |input|
      dead_cells << OpenStruct.new(tx_hash: input.previous_output.tx_hash,
                                   cell_index: input.previous_output.index)
    end
    tx_hash = tx.hash
    tx.outputs.each_index do |i|
      if tx.outputs[i].type
        type_code_hash = tx.outputs[i].type.code_hash
        type_args = tx.outputs[i].type.args
        type_hash_type = tx.outputs[i].type.hash_type
      else
        type_code_hash = ""
        type_args = ""
        type_hash_type = ""
      end
      live_cells << OpenStruct.new(tx_hash: tx_hash,
                                   cell_index: i,
                                   capacity: tx.outputs[i].capacity.to_i,
                                   lock_code_hash: tx.outputs[i].lock.code_hash,
                                   lock_args: tx.outputs[i].lock.args,
                                   lock_hash_type: tx.outputs[i].lock.hash_type,
                                   type_code_hash: type_code_hash,
                                   type_args: type_args,
                                   type_hash_type: type_hash_type,
                                   height: height)
    end
  end
  OpenStruct.new(live_cells: live_cells, dead_cells: dead_cells)
end

def get_tip_block_number
  api = CKB::API.new
  api.get_tip_block_number.to_i
end

def getLiveCellByTxHashIndex(tx_hash, index)
  out_point = CKB::Types::OutPoint.new(
                tx_hash: tx_hash,
                index: index
              )
  api = CKB::API.new
  cell_with_status = api.get_live_cell(out_point, true)
end

def system_script
  api = CKB::API.new
  system_group_outpoint = api.secp_group_out_point
  {
    name: "system",
    elf_path: "system",
    code_hash: api.secp_cell_type_hash,
    hash_type: "type",
    tx_hash: system_group_outpoint.tx_hash,
    index: CKB::Utils::to_hex(system_group_outpoint.index),
    dep_type: "dep_group"
  }
end

# send transaction which signed
# @param transaction [CKB::Transaction]
def send_raw_transaction(transaction)
  api = CKB::API.new
  tx_hash = api.send_transaction(transaction)
  # wait for tx committed
  count = 0
  while true do
    sleep(3)
    count += 1
    raise "deploy contract timeout" if count > 200

    ret = api.get_transaction(tx_hash)
    if ret.tx_status.status == "committed"
      return tx_hash
    end
  end
end

def min_output_capacity
  min_output = CKB::Types::Output.new(
    capacity: 0,
    lock:  CKB::Types::Script.generate_lock(
              "0x0000000000000000000000000000000000000000",
              "0x0000000000000000000000000000000000000000000000000000000000000000",
              "data"
            )
  )
  min_output.calculate_min_capacity("0x")
end

# @return [CKB::Types::Output[]]
def get_unspent_cells(lock_hash, from, to)
  api = CKB::API.new
  to = api.get_tip_block_number.to_i if to == 0
  results = []
  current_from = from
  while current_from <= to
    current_to = [current_from + 100, to].min
    cells = api.get_cells_by_lock_hash(lock_hash, current_from, current_to)
    results.concat(cells)
    current_from = current_to + 1
  end
  results
end

def get_balance(lock_hash)
  get_unspent_cells(lock_hash, 1, 0).map { |cell| cell.capacity.to_i }.reduce(0, &:+)
end

def gather_inputs(lock_hash, capacity, min_capacity, from, to, is_assert)
  raise "capacity cannot be less than #{min_capacity}" if capacity < min_capacity

  input_capacities = 0
  inputs = []
  get_unspent_cells(lock_hash, from, to).each do |cell|
    input = CKB::Types::Input.new(
      previous_output: cell.out_point,
      since: 0
    )
    inputs << input
    input_capacities += cell.capacity.to_i

    diff = input_capacities - capacity - MIN_FEE
    break if diff >= min_capacity || diff.zero?
  end

  raise "Capacity not enough!" if input_capacities < capacity and is_assert

  OpenStruct.new(inputs: inputs, capacities: input_capacities)
end

def getLiveCells(lock_hash, capacity, from, to)
  min_capacity = min_output_capacity()

  i = gather_inputs(
    lock_hash,
    capacity,
    min_capacity,
    from,
    to,
    false
  )
end

def fake_witnesses(n)
  witnesses = []
  n.times do
    witnesses << CKB::Types::Witness.new
  end
  witnesses
end

class Client
  attr_reader :api
  attr_reader :key

  def initialize(privkey)
    @api = CKB::API.new
    @key = CKB::Key.new(privkey)
  end

  def pubkey
    @key.pubkey
  end

  def blake160
    @key.address.blake160
  end

  def address
    @key.address.to_s
  end

  # @return [CKB::Types::Script]
  def lock
    CKB::Types::Script.generate_lock(
      blake160,
      api.secp_cell_type_hash,
      "type"
    )
  end

  def lock_hash
    @lock_hash ||= lock.compute_hash
  end

  # for Operators
  def deployContract(elf_path)
    contract_name = File.basename(elf_path)
    elf_bin = File.binread(elf_path)
    code_len = elf_bin.length
    code_hash = CKB::Utils.bin_to_hex(CKB::Blake2b.digest(elf_bin))

    capacity = code_len * 10 ** 8
    output= CKB::Types::Output.new(
      capacity: capacity,
      lock: lock
    )
    output_data = "0x#{elf_bin.unpack1('H*')}"
    capacity = output.calculate_min_capacity(output_data)
    output.capacity = capacity

    change_output = CKB::Types::Output.new(
      capacity: 0,
      lock: lock
    )
    change_output_data = "0x"

    i = gather_inputs(
      lock_hash,
      capacity,
      min_output_capacity(),
      1,
      0,
      true
    )
    input_capacities = i.capacities

    outputs = [output]
    outputs_data = [output_data]
    change_output.capacity = input_capacities - capacity - MIN_FEE
    if change_output.capacity.to_i > 0
      outputs << change_output
      outputs_data << change_output_data
    end

    tx = CKB::Types::Transaction.new(
      version: 0,
      cell_deps: [
        CKB::Types::CellDep.new(out_point: api.secp_group_out_point, dep_type: "dep_group")
      ],
      inputs: i.inputs,
      outputs: outputs,
      outputs_data: outputs_data,
      witnesses: fake_witnesses(i.inputs.length)
    )

    tx = tx.sign(key)
    send_raw_transaction(tx)

    # wait for tx committed
    count = 0
    while true do
      sleep(3)
      count += 1
      raise "deploy contract timeout" if count > 200

      ret = api.get_transaction(tx.hash)
      if ret.tx_status.status == "committed"
        return {name: contract_name,
                               elf_path: elf_path,
                               code_hash: code_hash,
                               hash_type: "data",
                               tx_hash: tx.hash,
                               index: "0x0",
                               dep_type: "code"
                              }
      end
    end
  end

  def sign_transaction(tx)
    stx = tx.sign(key)
    puts "tx_hash:", CKB::Utils.bin_to_hex(stx.hash)
    witnesses = []
    stx.witnesses.map do |witness|
      case witness
      when CKB::Types::Witness
        witnesses << CKB::Serializers::WitnessArgsSerializer.from(witness).serialize
      else
        witnesses << witness
      end
    end
    witnesses
  end

  def simple_sign_transaction(tx)
    stx = tx.sign(key)
    puts "tx_hash:", CKB::Utils.bin_to_hex(stx.hash)
    tx_hash = stx.hash

    blake2b = CKB::Blake2b.new
    blake2b.update(CKB::Utils.hex_to_bin(tx_hash))
    message = blake2b.hexdigest
    signature = key.sign_recoverable(message)

    witnesses = []
    tx.inputs.each do |i|
      witnesses << signature
    end
    witnesses
  end

  # send transaction which unsigned
  # @param transaction [CKB::Transaction]
  def send_transaction(tx)
    stx = sign_transaction(tx)
    send_raw_transaction(stx)
  end
end
