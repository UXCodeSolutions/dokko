class RealEstateProperty {
  final String id;
  final String title;
  final String? description;
  final String propertyType;
  final String operationType;
  final String status;
  
  final double? priceSale;
  final double? priceRent;
  final String? currency;
  final double? hoaFee;
  final double? propertyTax;
  
  final int? bedrooms;
  final double? bathrooms;
  final int? parkingSpots;
  final double? squareMetersBuilt;
  final double? squareMetersLand;
  final int? yearBuilt;
  
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? country;
  
  final List<String> images;
  final List<String> features;
  
  final String? mlsId;
  final String? virtualTourUrl;

  RealEstateProperty({
    required this.id,
    required this.title,
    this.description,
    required this.propertyType,
    required this.operationType,
    required this.status,
    this.priceSale,
    this.priceRent,
    this.currency,
    this.hoaFee,
    this.propertyTax,
    this.bedrooms,
    this.bathrooms,
    this.parkingSpots,
    this.squareMetersBuilt,
    this.squareMetersLand,
    this.yearBuilt,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.country,
    this.images = const [],
    this.features = const [],
    this.mlsId,
    this.virtualTourUrl,
  });

  factory RealEstateProperty.fromJson(Map<String, dynamic> json) {
    return RealEstateProperty(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      propertyType: json['property_type'],
      operationType: json['operation_type'],
      status: json['status'] ?? 'available',
      
      priceSale: json['price_sale'] != null ? (json['price_sale'] as num).toDouble() : null,
      priceRent: json['price_rent'] != null ? (json['price_rent'] as num).toDouble() : null,
      currency: json['currency'],
      hoaFee: json['hoa_fee'] != null ? (json['hoa_fee'] as num).toDouble() : null,
      propertyTax: json['property_tax'] != null ? (json['property_tax'] as num).toDouble() : null,
      
      bedrooms: json['bedrooms'],
      bathrooms: json['bathrooms'] != null ? (json['bathrooms'] as num).toDouble() : null,
      parkingSpots: json['parking_spots'],
      squareMetersBuilt: json['square_meters_built'] != null ? (json['square_meters_built'] as num).toDouble() : null,
      squareMetersLand: json['square_meters_land'] != null ? (json['square_meters_land'] as num).toDouble() : null,
      yearBuilt: json['year_built'],
      
      address: json['address'],
      city: json['city'],
      state: json['state'],
      zipCode: json['zip_code'],
      country: json['country'],
      
      images: json['images'] != null ? List<String>.from(json['images']) : [],
      features: json['features'] != null ? List<String>.from(json['features']) : [],
      
      mlsId: json['mls_id'],
      virtualTourUrl: json['virtual_tour_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'property_type': propertyType,
      'operation_type': operationType,
      'status': status,
      'price_sale': priceSale,
      'price_rent': priceRent,
      'currency': currency,
      'hoa_fee': hoaFee,
      'property_tax': propertyTax,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'parking_spots': parkingSpots,
      'square_meters_built': squareMetersBuilt,
      'square_meters_land': squareMetersLand,
      'year_built': yearBuilt,
      'address': address,
      'city': city,
      'state': state,
      'zip_code': zipCode,
      'country': country,
      'images': images,
      'features': features,
      'mls_id': mlsId,
      'virtual_tour_url': virtualTourUrl,
    };
  }
}

class RealEstateLead {
  final String id;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? email;
  final String? source;
  final String status;
  
  final String? interestedIn;
  final double? budgetMin;
  final double? budgetMax;
  final List<String> preferredCities;
  final int? minBedrooms;
  
  final String? assignedAgentId;
  final String? interestedPropertyId;
  final String? notes;

  RealEstateLead({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.email,
    this.source,
    required this.status,
    this.interestedIn,
    this.budgetMin,
    this.budgetMax,
    this.preferredCities = const [],
    this.minBedrooms,
    this.assignedAgentId,
    this.interestedPropertyId,
    this.notes,
  });

  factory RealEstateLead.fromJson(Map<String, dynamic> json) {
    return RealEstateLead(
      id: json['id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      phone: json['phone'],
      email: json['email'],
      source: json['source'],
      status: json['status'] ?? 'new',
      interestedIn: json['interested_in'],
      budgetMin: json['budget_min'] != null ? (json['budget_min'] as num).toDouble() : null,
      budgetMax: json['budget_max'] != null ? (json['budget_max'] as num).toDouble() : null,
      preferredCities: json['preferred_cities'] != null ? List<String>.from(json['preferred_cities']) : [],
      minBedrooms: json['min_bedrooms'],
      assignedAgentId: json['assigned_agent_id'],
      interestedPropertyId: json['interested_property_id'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'email': email,
      'source': source,
      'status': status,
      'interested_in': interestedIn,
      'budget_min': budgetMin,
      'budget_max': budgetMax,
      'preferred_cities': preferredCities,
      'min_bedrooms': minBedrooms,
      'assigned_agent_id': assignedAgentId,
      'interested_property_id': interestedPropertyId,
      'notes': notes,
    };
  }
}

class RealEstateDossier {
  final String id;
  final String? propertyId;
  final String? leadId;
  final String fileUrl;
  final DateTime createdAt;

  RealEstateDossier({
    required this.id,
    this.propertyId,
    this.leadId,
    required this.fileUrl,
    required this.createdAt,
  });

  factory RealEstateDossier.fromJson(Map<String, dynamic> json) {
    return RealEstateDossier(
      id: json['id'],
      propertyId: json['property_id'],
      leadId: json['lead_id'],
      fileUrl: json['file_url'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class RealEstateAgent {
  final String id;
  final String? userId;
  final String firstName;
  final String lastName;
  final String? licenseNumber;
  final String? phone;
  final String? email;
  final double commissionRate;
  final bool isActive;

  RealEstateAgent({
    required this.id,
    this.userId,
    required this.firstName,
    required this.lastName,
    this.licenseNumber,
    this.phone,
    this.email,
    this.commissionRate = 0.0,
    this.isActive = true,
  });

  factory RealEstateAgent.fromJson(Map<String, dynamic> json) {
    return RealEstateAgent(
      id: json['id'],
      userId: json['user_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      licenseNumber: json['license_number'],
      phone: json['phone'],
      email: json['email'],
      commissionRate: json['commission_rate'] != null ? (json['commission_rate'] as num).toDouble() : 0.0,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'license_number': licenseNumber,
      'phone': phone,
      'email': email,
      'commission_rate': commissionRate,
      'is_active': isActive,
    };
  }
}

class RealEstateCommission {
  final String id;
  final String propertyId;
  final String agentId;
  final double amount;
  final double? commissionPercentage;
  final String status;
  final DateTime? paymentDate;
  final DateTime createdAt;

  final RealEstateProperty? property;
  final RealEstateAgent? agent;

  RealEstateCommission({
    required this.id,
    required this.propertyId,
    required this.agentId,
    required this.amount,
    this.commissionPercentage,
    required this.status,
    this.paymentDate,
    required this.createdAt,
    this.property,
    this.agent,
  });

  factory RealEstateCommission.fromJson(Map<String, dynamic> json) {
    return RealEstateCommission(
      id: json['id'],
      propertyId: json['property_id'],
      agentId: json['agent_id'],
      amount: (json['amount'] as num).toDouble(),
      commissionPercentage: json['commission_percentage'] != null ? (json['commission_percentage'] as num).toDouble() : null,
      status: json['status'],
      paymentDate: json['payment_date'] != null ? DateTime.parse(json['payment_date']) : null,
      createdAt: DateTime.parse(json['created_at']),
      property: json['property'] != null ? RealEstateProperty.fromJson(json['property']) : null,
      agent: json['agent'] != null ? RealEstateAgent.fromJson(json['agent']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'property_id': propertyId,
      'agent_id': agentId,
      'amount': amount,
      'commission_percentage': commissionPercentage,
      'status': status,
      'payment_date': paymentDate?.toIso8601String(),
    };
  }
}
