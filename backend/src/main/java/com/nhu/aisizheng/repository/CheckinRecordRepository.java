package com.nhu.aisizheng.repository;

import com.nhu.aisizheng.model.CheckinRecord;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface CheckinRecordRepository extends JpaRepository<CheckinRecord, Long> {

    /** 查询用户今日某类型打卡记录 */
    @Query("SELECT c FROM CheckinRecord c WHERE c.userId = :userId "
         + "AND c.checkinType = :type AND c.checkinTime >= :start AND c.checkinTime < :end "
         + "AND c.status = 'SUCCESS'")
    Optional<CheckinRecord> findTodayCheckin(
            @Param("userId") Long userId,
            @Param("type") String type,
            @Param("start") LocalDateTime start,
            @Param("end") LocalDateTime end);

    @Query("SELECT c FROM CheckinRecord c WHERE c.userId = :userId "
         + "AND c.checkinType = :type AND c.siteId = :siteId "
         + "AND c.checkinTime >= :start AND c.checkinTime < :end "
         + "AND c.status = 'SUCCESS'")
    Optional<CheckinRecord> findTodayCheckinAtSite(
            @Param("userId") Long userId,
            @Param("type") String type,
            @Param("siteId") Long siteId,
            @Param("start") LocalDateTime start,
            @Param("end") LocalDateTime end);

    @Query("SELECT c FROM CheckinRecord c WHERE c.userId = :userId "
         + "AND c.checkinType = 'CLASS' AND c.sessionId = :sessionId "
         + "AND c.status = 'SUCCESS'")
    Optional<CheckinRecord> findSuccessfulClassSessionCheckin(
            @Param("userId") Long userId,
            @Param("sessionId") Long sessionId);

    /** 查询用户打卡历史 */
    Page<CheckinRecord> findByUserIdOrderByCheckinTimeDesc(Long userId, Pageable pageable);

    /** 查询指定打卡点当日成功打卡数 */
    @Query("SELECT COUNT(c) FROM CheckinRecord c WHERE c.siteId = :siteId "
         + "AND c.checkinTime >= :start AND c.checkinTime < :end AND c.status = 'SUCCESS'")
    long countTodayBySite(
            @Param("siteId") Long siteId,
            @Param("start") LocalDateTime start,
            @Param("end") LocalDateTime end);

    /** 查询班级当日打卡状态 */
    @Query("SELECT c FROM CheckinRecord c WHERE c.userId IN :userIds "
         + "AND c.checkinType = :type AND c.checkinTime >= :start AND c.checkinTime < :end")
    List<CheckinRecord> findTodayByUsers(
            @Param("userIds") List<Long> userIds,
            @Param("type") String type,
            @Param("start") LocalDateTime start,
            @Param("end") LocalDateTime end);

    List<CheckinRecord> findByCheckinTimeBetweenOrderByCheckinTimeDesc(LocalDateTime start, LocalDateTime end);

    List<CheckinRecord> findByCheckinTypeAndCheckinTimeBetween(String checkinType, LocalDateTime start, LocalDateTime end);

    List<CheckinRecord> findBySessionId(Long sessionId);

    List<CheckinRecord> findByAppealStatusOrderByAppealedAtDesc(String appealStatus);

    /** 查询连续未打卡的学生 */
    @Query(value = "SELECT c.user_id FROM checkin_record c "
         + "WHERE c.checkin_type = :type AND c.checkin_time >= :since "
         + "AND c.status = 'SUCCESS' GROUP BY c.user_id", nativeQuery = true)
    List<Long> findCheckedInUsersSince(
            @Param("type") String type,
            @Param("since") LocalDateTime since);
}
