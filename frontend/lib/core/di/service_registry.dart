import '../../services/services.dart';

/// App-wide dependency container for frontend services.
///
/// This keeps service wiring in one place and prevents ad-hoc service
/// instantiation across screens.
class ServiceRegistry {
  ServiceRegistry._();

  static final ServiceRegistry instance = ServiceRegistry._();

  final ApiClient apiClient = ApiClient();

  late final AuthService authService = AuthService(client: apiClient);
  late final ProfileService profileService = ProfileService(client: apiClient);
  late final StorageService storageService = StorageService(client: apiClient);
  late final ClothingService clothingService = ClothingService(client: apiClient);
  late final OutfitService outfitService = OutfitService(client: apiClient);
  late final AccessoryService accessoryService = AccessoryService(
    client: apiClient,
  );
  late final RecommendationService recommendationService = RecommendationService(
    client: apiClient,
  );
  late final AdminService adminService = AdminService(client: apiClient);
  late final MiscService miscService = MiscService(client: apiClient);
  late final FeedbackService feedbackService = FeedbackService(
    client: apiClient,
  );
}
