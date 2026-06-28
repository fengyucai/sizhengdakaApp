package com.nhu.aisizheng.repository;

import com.nhu.aisizheng.model.LeaveRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.time.LocalDateTime;

@Repository
public interface LeaveRequestRepository extends JpaRepository<LeaveRequest, Long> {

    List<LeaveRequest> findByUserIdOrderByCreatedAtDesc(Long userId);

    List<LeaveRequest> findAllByOrderByCreatedAtDesc();

    List<LeaveRequest> findByUserIdAndStatusAndStartTimeLessThanEqualAndEndTimeGreaterThanEqual(
            Long userId, String status, LocalDateTime endTime, LocalDateTime startTime);
}
