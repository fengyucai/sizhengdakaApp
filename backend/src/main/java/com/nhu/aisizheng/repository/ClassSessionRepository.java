package com.nhu.aisizheng.repository;

import com.nhu.aisizheng.model.ClassSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface ClassSessionRepository extends JpaRepository<ClassSession, Long> {

    List<ClassSession> findByStatusAndSignEndTimeGreaterThanEqualOrderByStartTimeAsc(String status, LocalDateTime now);

    List<ClassSession> findByClassIdAndStatusAndStartTimeBetweenOrderByStartTimeAsc(
            Long classId, String status, LocalDateTime start, LocalDateTime end);
}
