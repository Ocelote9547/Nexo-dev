class NexoException implements Exception {
  final String message;
  const NexoException(this.message);
  @override
  String toString() => 'NexoException: $message';
}

class ValidationException extends NexoException {
  const ValidationException(super.message);
}

class NotFoundException extends NexoException {
  const NotFoundException(super.message);
}

class DatabaseException extends NexoException {
  const DatabaseException(super.message);
}

class StorageException extends NexoException {
  const StorageException(super.message);
}
