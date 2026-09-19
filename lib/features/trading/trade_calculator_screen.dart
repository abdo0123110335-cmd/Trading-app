import 'package:flutter/material.dart';

import 'package:binance_spot_pro/core/theme/app_theme.dart';
import 'package:binance_spot_pro/services/trading_engine/entry_sl_tp_calculator.dart';

class TradeCalculatorScreen extends StatefulWidget {
  const TradeCalculatorScreen({super.key});

  @override
  State<TradeCalculatorScreen> createState() => _TradeCalculatorScreenState();
}

class _TradeCalculatorScreenState extends State<TradeCalculatorScreen> {
  final _entryController = TextEditingController(text: '100000');
  final _stopLossController = TextEditingController(text: '98000');
  final _riskController = TextEditingController(text: '50');
  double _tp1Multiplier = 1.5;
  double _tp2Multiplier = 3.0;
  TpCloseMode _closeMode = TpCloseMode.closeAtTp1;
  bool _closeHalfAtTp1 = false;

  EntrySlTpResult? get _result {
    final entry = double.tryParse(_entryController.text);
    final stopLoss = double.tryParse(_stopLossController.text);
    final risk = double.tryParse(_riskController.text);
    if (entry == null || stopLoss == null || risk == null || entry == stopLoss) return null;
    return calculateEntrySlTp(
      EntrySlTpInput(
        entry: entry,
        stopLoss: stopLoss,
        accountRiskUsdt: risk,
        tp1Multiplier: _tp1Multiplier,
        tp2Multiplier: _tp2Multiplier,
        closeMode: _closeMode,
        closeHalfAtTp1: _closeHalfAtTp1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Entry / SL / TP Calculator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _numField('Entry', _entryController),
          _numField('Stop Loss', _stopLossController),
          _numField('Risk (USDT)', _riskController),
          const SizedBox(height: 8),
          Text('TP1 Multiplier: ${_tp1Multiplier.toStringAsFixed(1)}x'),
          Slider(
            value: _tp1Multiplier,
            min: 0.5,
            max: 5,
            divisions: 45,
            label: '${_tp1Multiplier.toStringAsFixed(1)}x',
            onChanged: (v) => setState(() => _tp1Multiplier = v),
          ),
          Text('TP2 Multiplier: ${_tp2Multiplier.toStringAsFixed(1)}x'),
          Slider(
            value: _tp2Multiplier,
            min: 0.5,
            max: 10,
            divisions: 95,
            label: '${_tp2Multiplier.toStringAsFixed(1)}x',
            onChanged: (v) => setState(() => _tp2Multiplier = v),
          ),
          const SizedBox(height: 8),
          SegmentedButton<TpCloseMode>(
            segments: const [
              ButtonSegment(value: TpCloseMode.closeAtTp1, label: Text('Close at TP1')),
              ButtonSegment(value: TpCloseMode.closeAtTp2, label: Text('Close at TP2')),
              ButtonSegment(value: TpCloseMode.custom, label: Text('Custom')),
            ],
            selected: {_closeMode},
            onSelectionChanged: (s) => setState(() => _closeMode = s.first),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Close 50% at TP1'),
            value: _closeHalfAtTp1,
            onChanged: (v) => setState(() => _closeHalfAtTp1 = v),
          ),
          const SizedBox(height: 16),
          if (result == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Enter a valid entry, stop loss and risk to see results.'),
              ),
            )
          else
            _ResultCard(result: result),
        ],
      ),
    );
  }

  Widget _numField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  @override
  void dispose() {
    _entryController.dispose();
    _stopLossController.dispose();
    _riskController.dispose();
    super.dispose();
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final EntrySlTpResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _resultRow('Risk Amount', '${result.riskAmount.toStringAsFixed(2)} USDT'),
            _resultRow('Risk %', '${result.riskPercent.toStringAsFixed(2)}%'),
            _resultRow('Position Size', result.positionSize.toStringAsFixed(6)),
            _resultRow('TP1', result.tp1.toStringAsFixed(4), color: MarketColors.bullish),
            _resultRow('TP2', result.tp2.toStringAsFixed(4), color: MarketColors.bullish),
            _resultRow('R:R to TP1', '1 : ${result.riskRewardTp1.toStringAsFixed(2)}'),
            _resultRow('R:R to TP2', '1 : ${result.riskRewardTp2.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: MarketColors.neutral)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
