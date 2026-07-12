// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lesson.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LessonAdapter extends TypeAdapter<Lesson> {
  @override
  final int typeId = 0;

  @override
  Lesson read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Lesson(
      id: fields[0] as String,
      youtubeUrl: fields[1] as String,
      order: fields[2] as int,
      month: fields[3] as int,
      title: fields[4] as String,
      thumbnailUrl: fields[5] as String,
      position: fields[7] as int,
      completed: fields[6] as bool,
      notification: fields[8] as String?,
      read: fields[9] as bool,
      startSecond: fields[10] as int?,
      endSecond: fields[11] as int?,
      partTitle: fields[12] as String?,
      partNumber: fields[13] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Lesson obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.youtubeUrl)
      ..writeByte(2)
      ..write(obj.order)
      ..writeByte(3)
      ..write(obj.month)
      ..writeByte(4)
      ..write(obj.title)
      ..writeByte(5)
      ..write(obj.thumbnailUrl)
      ..writeByte(6)
      ..write(obj.completed)
      ..writeByte(7)
      ..write(obj.position)
      ..writeByte(8)
      ..write(obj.notification)
      ..writeByte(9)
      ..write(obj.read)
      ..writeByte(10)
      ..write(obj.startSecond)
      ..writeByte(11)
      ..write(obj.endSecond)
      ..writeByte(12)
      ..write(obj.partTitle)
      ..writeByte(13)
      ..write(obj.partNumber);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LessonAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
