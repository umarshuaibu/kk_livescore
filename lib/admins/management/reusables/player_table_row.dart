import 'package:flutter/material.dart';
import '../models/player_model.dart';

DataRow buildPlayerDataRow({
  required Player player,
  required void Function(Player) onEdit,
  required void Function(Player) onTransfer,
  required void Function(Player) onDelete,
}) {
  
  return DataRow(cells: [
    DataCell(Text(player.name)),
    DataCell(Text(player.team ?? '-')),
    DataCell(Text(player.state)),
    DataCell(Row(
      children: [
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.blue),
          tooltip: 'Edit Player',
          onPressed: () => onEdit(player),
        ),
        IconButton(
          icon: const Icon(Icons.swap_horiz, color: Colors.orange),
          tooltip: 'Transfer Player',
          onPressed: () => onTransfer(player),
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          tooltip: 'Delete Player',
          onPressed: () => onDelete(player),
        ),
      ],
      
    )),
  ]);
}
