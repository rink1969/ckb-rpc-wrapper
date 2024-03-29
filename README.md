# dependencies

### ruby

see [doc](https://www.ruby-lang.org/zh_cn/documentation/installation/)

need >= 2.4.0

### Bundler

```shell
gem install bundler
```

### install libs

```shell
bundle
```

# run
Firstly setup ckb node.
```shell
$ ./server.rb
[2019-10-17 16:49:11] INFO  WEBrick 1.4.2
[2019-10-17 16:49:11] INFO  ruby 2.6.5 (2019-10-01) [x86_64-linux]
[2019-10-17 16:49:11] INFO  WEBrick::HTTPServer#start: pid=17334 port=8999
```

# examples
### deployContract
##### args
1. privkey of deployer.
2. path of elf file(constract).

##### result
constract information.

```shell
curl -X POST --data '{"jsonrpc": "2.0", "method":"deployContract", "params":["0x3d20089223fa9a6c07c1d2cc69c1ed87e2477b1240f63317e0a1fb1e70d3188f","/path/to/always_success"], "id": 1}' http://localhost:8999
```
```json
{"jsonrpc":"2.0","result":{"name":"always_success","elf_path":"/path/to/always_success","code_hash":"0x0274eb897aef04482f737d3fbee9c5983e510622c6cecd78f545e433ae6e70f0","hash_type":"data","tx_hash":"0xd3012777fce1fc9ef16e08a072747ea868dd6492d646b81b45cc90abe4c328bf","index":"0x0","dep_type":"code"},"id":1}
```

### getHDUserInfo
##### args
1. index of HD User.

##### result
information of user.

```shell
curl -X POST --data '{"jsonrpc": "2.0", "method":"getHDUserInfo", "params":[100], "id": 1}' http://localhost:8999
```
```json
{"jsonrpc":"2.0","result":{"privkey":"0xc1d3653395d6dc74e11d97a3ca2e4175067b80f525a3d8a2baf9129de4bbbbd3","pubkey":"0x03bda204b8ac489fc8dfa388fb0c282b0a8d81a799a83497bfeeb606b12b002685","blake160":"0x87594e15061b83acfe27b68cc5d30c069470cdd5","address":"ckt1qyqgwk2wz5rphqavlcnmdrx96vxqd9rseh2ssf7pfk"},"id":1}
```

### getCellByTxHashIndex
##### args
1. transaction hash.
2. index of cell in transaction.

##### result
content and status of cell.

```shell
curl -X POST --data '{"jsonrpc": "2.0", "method":"getCellByTxHashIndex", "params":["0xb815a396c5226009670e89ee514850dcde452bca746cdd6b41c104b50e559c70", 0], "id": 1}' http://localhost:8999
```
```json
{"jsonrpc":"2.0","result":{"cell":{"output":{"capacity":"0x2b95fd500","lock":{"code_hash":"0x0000000000000000000000000000000000000000000000000000000000000000","args":"0x","hash_type":"data"},"type":null},"data":{"content":"0x02000000ee046ce2baeda575266d4164f394c53f66009f64759f7a9f12a014c692e7939003000000ee046ce2baeda575266d4164f394c53f66009f64759f7a9f12a014c692e7939001000000","hash":"0xbd018d271d4e834a2481559e40ea5b24258e6e58e1f3e35daa8fc3af04ed3408"}},"status":"live"},"id":1}
```

### getUserInfo
##### args
1. privkey of user.

##### result
information of user.

```shell
curl -X POST --data '{"jsonrpc": "2.0", "method":"getUserInfo", "params":["0xc1d3653395d6dc74e11d97a3ca2e4175067b80f525a3d8a2baf9129de4bbbbd3"], "id": 1}' http://localhost:8999
```
```json
{"jsonrpc":"2.0","result":{"privkey":"0xc1d3653395d6dc74e11d97a3ca2e4175067b80f525a3d8a2baf9129de4bbbbd3","pubkey":"0x03bda204b8ac489fc8dfa388fb0c282b0a8d81a799a83497bfeeb606b12b002685","blake160":"0x87594e15061b83acfe27b68cc5d30c069470cdd5","address":"ckt1qyqgwk2wz5rphqavlcnmdrx96vxqd9rseh2ssf7pfk"},"id":1}
```

### lockHash
##### args
1. code hash. You can find it in result of `deployContract`.
2. args. It's always `blake160` of user. See `getUserInfo` or `getHDUserInfo`.
3. hash type. "type" or "data".

##### result
hash of lock script structure.

```shell
curl -X POST --data '{"jsonrpc": "2.0", "method":"lockHash", "params":["0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8", "0x4a88cef22e4e71c48c40da51c1d6bd16daa97aa7", "type"], "id": 1}' http://localhost:8999
```
```json
{"jsonrpc":"2.0","result":"0x758c0a983a0fc742a3a5862ab2d4deb87fb99dac9ed325919fbb687805cd828d","id":1}
```

### queryLiveCellsByCapacity
##### args
1. lock hash. see `lockHash`.
2. capacity. Condition of stop collecting inputs.

##### result
inputs collected from chain.
And sum of capacity all these inputs. It should greater than capacity in args.

```shell
curl -X POST --data '{"jsonrpc": "2.0", "method":"queryLiveCellsByCapacity", "params":["0x758c0a983a0fc742a3a5862ab2d4deb87fb99dac9ed325919fbb687805cd828d", 200000000000], "id": 1}' http://localhost:8999
```
```json
{"jsonrpc":"2.0","result":{"inputs":[{"previous_output":{"tx_hash":"0x6677a8c53345f7011ecfa908ee62c099af9c40881164bc206db302d81fe5b60a","index":"0x0"},"since":"0x0"},{"previous_output":{"tx_hash":"0xdd7ca745ab704f5001dfd90713c8980dcd865175dbcd342a7d741ebbce98eb9b","index":"0x0"},"since":"0x0"}],"capacity":"407354152341"},"id":1}
```

### queryLiveCellsByHeights
##### args
1. lock hash. see `lockHash`.
2. from, to. Range of block number. see `blockNumber`.

##### result
inputs collected from chain.

```shell
curl -X POST --data '{"jsonrpc": "2.0", "method":"queryLiveCellsByHeights", "params":["0x758c0a983a0fc742a3a5862ab2d4deb87fb99dac9ed325919fbb687805cd828d", 155, 157], "id": 1}' http://localhost:8999
```
```json
{"jsonrpc":"2.0","result":{"inputs":[{"previous_output":{"tx_hash":"0xf6f4d282e896b2842b50a8209a021820bc9aabbd3ba200182c371dbe6aa5f62a","index":"0x0"},"since":"0x0"},{"previous_output":{"tx_hash":"0x79a025f64198b35338cb4d41aeeb7ee5329389b50265963b4f6261daf64d2f22","index":"0x0"},"since":"0x0"}],"capacity":"407337001917"},"id":1}
```

### sign
##### args
1. privkey of sender.
2. transaction(without signature in witnesses).

##### result
witnesses of the transaction. With WitnessArgs.

```shell
curl -X POST --data '{"jsonrpc": "2.0", "method":"sign", "params":["0xc1d3653395d6dc74e11d97a3ca2e4175067b80f525a3d8a2baf9129de4bbbbd3","{\"version\": \"0x0\", \"cell_deps\": [{\"out_point\": {\"tx_hash\": \"0x8918ec6031e131b6398e4e656fad08ccb3756e7bea0df81c160b845f9c4feff5\", \"index\": \"0x0\"}, \"dep_type\": \"code\"}], \"header_deps\": [], \"inputs\": [{\"previous_output\": {\"tx_hash\": \"0x9bba636392badc6f4ba4fcad05ad56ffb6c2645152ec4711b9726b9aba2df454\", \"index\": \"0x0\"}, \"since\": \"0x0\"}], \"outputs\": [{\"capacity\": \"0x174857a800\", \"lock\": {\"code_hash\": \"0x0274eb897aef04482f737d3fbee9c5983e510622c6cecd78f545e433ae6e70f0\", \"args\": \"0xfd03fd824f9b777f3671ab776bd694cc76e3c09d\", \"hash_type\": \"data\"}}], \"outputs_data\": [\"0x\"], \"witnesses\": [\"0x\"]}"], "id": 1}' http://localhost:8999
```
```json
{"jsonrpc":"2.0","result":["0x55000000100000005500000055000000410000009b5ed403679c262ae07c8734c2f0b493cc0ebf2ac8166687c6a841de68c4edc77ad179d5bab8bc0b9a299084c8b7846577e00292a5285360f0debb419864582c00"],"id":1}
```

### simpleSign
##### args
1. privkey of sender.
2. transaction(without signature in witnesses).

##### result
witnesses of the transaction. No WitnessArgs, only sign tx_hash.

```shell
same as sign, just replace method with simpleSign.
```
```json
{"jsonrpc":"2.0","result":["0xb42938e474df326f261d7afcb1a67c4c637895930763d968c19df9fe1f22d0391c4a831978de9860009e3acfcb757f39452db154e4a5c8f01ee42335c779615f00"],"id":1}
```

### sendRawTransaction
##### args
1. raw transaction(with signature in witnesses).

##### result
transaction hash.

```shell
similiar with sign, just append witnesses which get from sing.
```
```json
{"jsonrpc":"2.0","result":"0xb815a396c5226009670e89ee514850dcde452bca746cdd6b41c104b50e559c70","id":1}
```

### sendTransaction
##### args
1. privkey of sender.
2. transaction(without signature in witnesses).

##### result
transaction hash.

```shell
same as sign, just replace method with sendTransaction.
```
```json
{"jsonrpc":"2.0","result":"0xb815a396c5226009670e89ee514850dcde452bca746cdd6b41c104b50e559c70","id":1}
```

### systemScript
args:

##### result
information of system script(default lock script).

```shell
curl -X POST --data '{"jsonrpc": "2.0", "method":"systemScript", "params":[], "id": 1}' http://localhost:8999
```
```json
{"jsonrpc":"2.0","result":{"name":"system","elf_path":"system","code_hash":"0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8","hash_type":"type","tx_hash":"0xb815a396c5226009670e89ee514850dcde452bca746cdd6b41c104b50e559c70","index":"0x0","dep_type":"dep_group"},"id":1}
```

### blockNumber
args:

##### result
current block number.

```shell
curl -X POST --data '{"jsonrpc": "2.0", "method":"blockNumber", "params":[], "id": 1}' http://localhost:8999
```
```json
{"jsonrpc":"2.0","result":28962,"id":1}
```