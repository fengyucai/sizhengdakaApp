package com.nhu.aisizheng.repository;

import com.nhu.aisizheng.model.AuditLog;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface AuditLogRepository extends JpaRepository<AuditLog, Long> {

    List<AuditLog> findAllByOrderByCreatedAtDesc(Pageable pageable);

    List<AuditLog> findByUserIdOrderByCreatedAtDesc(Long userId, Pageable pageable);
}
