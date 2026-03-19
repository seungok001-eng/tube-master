import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel_model.dart';
import '../models/project_model.dart';
import '../models/api_key_model.dart';

class AppProvider extends ChangeNotifier {
  // API 키
  ApiKeyModel _apiKeys = ApiKeyModel();
  ApiKeyModel get apiKeys => _apiKeys;

  // 채널 목록
  List<ChannelModel> _channels = [];
  List<ChannelModel> get channels => _channels;
  List<ChannelModel> get activeChannels => _channels.where((c) => c.isActive).toList();

  // 프로젝트 목록
  List<ProjectModel> _projects = [];
  List<ProjectModel> get projects => _projects;

  // 현재 선택된 항목
  ChannelModel? _selectedChannel;
  ChannelModel? get selectedChannel => _selectedChannel;

  ProjectModel? _currentProject;
  ProjectModel? get currentProject => _currentProject;

  // 네비게이션
  int _selectedNavIndex = 0;
  int get selectedNavIndex => _selectedNavIndex;

  // 로딩 상태
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // 사이드바 확장
  bool _isSidebarExpanded = true;
  bool get isSidebarExpanded => _isSidebarExpanded;

  // 마지막으로 선택한 스크립트 모델
  ScriptAiModel _scriptModel = ScriptAiModel.geminiFlash;
  ScriptAiModel get scriptModel => _scriptModel;

  // 알림 목록
  final List<String> _notifications = [];
  List<String> get notifications => List.unmodifiable(_notifications);

  AppProvider() {
    _loadData();
  }

  void setNavIndex(int index) {
    _selectedNavIndex = index;
    notifyListeners();
  }

  void toggleSidebar() {
    _isSidebarExpanded = !_isSidebarExpanded;
    notifyListeners();
  }

  void selectChannel(ChannelModel? channel) {
    _selectedChannel = channel;
    _saveSelectedChannelId(channel?.id);
    notifyListeners();
  }

  void setCurrentProject(ProjectModel? project) {
    _currentProject = project;
    _saveCurrentProjectId(project?.id);
    notifyListeners();
  }

  void setScriptModel(ScriptAiModel model) {
    _scriptModel = model;
    notifyListeners();
    _saveScriptModel();
  }

  void addNotification(String message) {
    _notifications.insert(0, message);
    if (_notifications.length > 20) _notifications.removeLast();
    notifyListeners();
  }

  void clearNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  // ==================== 채널 관리 ====================

  Future<void> addChannel(ChannelModel channel) async {
    _channels.add(channel);
    notifyListeners();
    await _saveChannels();
  }

  Future<void> updateChannel(ChannelModel channel) async {
    final idx = _channels.indexWhere((c) => c.id == channel.id);
    if (idx != -1) {
      _channels[idx] = channel;
      if (_selectedChannel?.id == channel.id) _selectedChannel = channel;
      notifyListeners();
      await _saveChannels();
    }
  }

  Future<void> deleteChannel(String channelId) async {
    _channels.removeWhere((c) => c.id == channelId);
    if (_selectedChannel?.id == channelId) _selectedChannel = null;
    notifyListeners();
    await _saveChannels();
  }

  ChannelModel? getChannelById(String id) {
    try {
      return _channels.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // ==================== 프로젝트 관리 ====================

  Future<void> addProject(ProjectModel project) async {
    _projects.insert(0, project);
    notifyListeners();
    await _saveProjects();
  }

  Future<void> updateProject(ProjectModel project) async {
    final idx = _projects.indexWhere((p) => p.id == project.id);
    if (idx != -1) {
      _projects[idx] = project;
      if (_currentProject?.id == project.id) _currentProject = project;
      notifyListeners();
      await _saveProjects();
    }
  }

  Future<void> deleteProject(String projectId) async {
    _projects.removeWhere((p) => p.id == projectId);
    if (_currentProject?.id == projectId) _currentProject = null;
    notifyListeners();
    await _saveProjects();
  }

  List<ProjectModel> getProjectsByChannel(String channelId) {
    return _projects.where((p) => p.channelId == channelId).toList();
  }

  // ==================== API 키 관리 ====================

  Future<void> updateApiKeys(ApiKeyModel keys) async {
    _apiKeys = keys;
    notifyListeners();
    await _saveApiKeys();
  }

  // ==================== 데이터 영속성 ====================

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // API 키 로드
      final apiKeysJson = prefs.getString('api_keys');
      if (apiKeysJson != null) {
        _apiKeys = ApiKeyModel.fromJson(jsonDecode(apiKeysJson));
      }

      // 채널 로드
      final channelsJson = prefs.getString('channels');
      if (channelsJson != null) {
        final List<dynamic> list = jsonDecode(channelsJson);
        _channels = list.map((c) => ChannelModel.fromJson(c)).toList();
      }

      // 프로젝트 로드
      final projectsJson = prefs.getString('projects');
      if (projectsJson != null) {
        final List<dynamic> list = jsonDecode(projectsJson);
        _projects = list.map((p) => ProjectModel.fromJson(p)).toList();
      }

      // 마지막 선택 프로젝트 복원
      final lastProjectId = prefs.getString('current_project_id');
      if (lastProjectId != null) {
        try {
          _currentProject = _projects.firstWhere((p) => p.id == lastProjectId);
        } catch (_) {}
      }

      // 마지막 선택 채널 복원
      final lastChannelId = prefs.getString('selected_channel_id');
      if (lastChannelId != null) {
        try {
          _selectedChannel = _channels.firstWhere((c) => c.id == lastChannelId);
        } catch (_) {}
      }

      // 스크립트 모델 복원
      final savedModelIdx = prefs.getInt('script_model_index');
      if (savedModelIdx != null && savedModelIdx < ScriptAiModel.values.length) {
        _scriptModel = ScriptAiModel.values[savedModelIdx];
      }
    } catch (e) {
      debugPrint('데이터 로드 오류: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveChannels() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('channels', jsonEncode(_channels.map((c) => c.toJson()).toList()));
  }

  Future<void> _saveProjects() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('projects', jsonEncode(_projects.map((p) => p.toJson()).toList()));
  }

  Future<void> _saveApiKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_keys', jsonEncode(_apiKeys.toJson()));
  }

  Future<void> _saveCurrentProjectId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id != null) {
      await prefs.setString('current_project_id', id);
    } else {
      await prefs.remove('current_project_id');
    }
  }

  Future<void> _saveSelectedChannelId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id != null) {
      await prefs.setString('selected_channel_id', id);
    } else {
      await prefs.remove('selected_channel_id');
    }
  }

  Future<void> _saveScriptModel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('script_model_index', _scriptModel.index);
  }
}
