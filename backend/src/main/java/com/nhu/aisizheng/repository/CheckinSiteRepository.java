package com.nhu.aisizheng.repository;

import com.nhu.aisizheng.model.CheckinSite;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CheckinSiteRepository extends JpaRepository<CheckinSite, Long> {

    List<CheckinSite> findBySiteTypeAndStatus(String siteType, String status);

    Optional<CheckinSite> findBySiteTypeAndStatusAndId(String siteType, String status, Long id);
}
